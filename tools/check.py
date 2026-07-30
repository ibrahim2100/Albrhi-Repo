"""Pre-build checks for every tweak in this repository.

Every rule here exists because that exact mistake reached CI at least once.

The rules themselves are written against one tweak, using paths relative to its
own directory -- 'src/**', 'control'. When run from the repository root this
file re-executes itself once per directory under tweaks/, with the working
directory moved there. That keeps eight rules that were each tightened against a
real false positive completely untouched: generalising them in place would have
meant rewriting the part of this file that is most expensive to get wrong.
"""
import re
import glob
import collections
import os
import subprocess
import sys

TWEAKS_DIR = 'tweaks'

if os.path.isdir(TWEAKS_DIR):
    tweaks = sorted(name for name in os.listdir(TWEAKS_DIR)
                    if os.path.isfile(os.path.join(TWEAKS_DIR, name, 'control')))
    if not tweaks:
        print('FAIL  no tweak found under %s/ (each needs its own control)' % TWEAKS_DIR)
        raise SystemExit(1)

    script = os.path.abspath(__file__)
    failed = []
    for name in tweaks:
        # flush=True, or the header sits in this process's buffer while the child
        # writes straight to the terminal and every heading lands after its output.
        print('=== %s ===' % name, flush=True)
        result = subprocess.run([sys.executable, script],
                                cwd=os.path.join(TWEAKS_DIR, name))
        if result.returncode:
            failed.append(name)
        print()

    if failed:
        print('FAILED: %s' % ', '.join(failed))
        raise SystemExit(1)

    print('ALL TWEAKS CLEAN')
    raise SystemExit(0)

SRC = (glob.glob('src/**/*.x', recursive=True)
       + glob.glob('src/**/*.xm', recursive=True)
       + glob.glob('src/**/*.m', recursive=True))
HDR = glob.glob('src/**/*.h', recursive=True)
LOGOS = [p for p in SRC if p.endswith(('.x', '.xm'))]

problems = []


def report(msg):
    problems.append(msg)


# 1. Duplicate @interface definitions.
#
# Across every file, not just within each header. Checking headers alone let a
# feature redeclare IGCoreTextView in its own .xm while InstagramHeaders.h already
# had it, which is the same "duplicate interface" build failure the rule exists to
# prevent — it was simply looking in half the places.
#
# The colon in the pattern keeps class extensions @interface Foo () and categories
# @interface Foo (Bar) out of it; only real declarations count.
declared = collections.defaultdict(list)

for path in HDR + SRC:
    text = open(path, encoding='utf-8').read()
    for name in re.findall(r'^@interface\s+(\w+)\s*:', text, re.M):
        declared[name].append(path)

for name in sorted(declared):
    places = declared[name]
    if len(places) > 1:
        report('duplicate @interface %s in %s' % (name, ', '.join(sorted(set(places)))))

# 2. Brace balance and %hook/%end pairing.
for path in SRC:
    text = open(path, encoding='utf-8').read()
    hooks = len(re.findall(r'^%hook', text, re.M))
    ends = len(re.findall(r'^%end', text, re.M))
    depth, first_negative, line = 0, None, 1
    for ch in text:
        if ch == '\n':
            line += 1
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth < 0 and first_negative is None:
                first_negative = line
    if hooks != ends or depth or first_negative:
        report('structure broken in %s (hook=%d end=%d depth=%d neg@%s)'
               % (path, hooks, ends, depth, first_negative))

# 3. Hooked classes that use properties but have no @interface.
declared = set()
for path in HDR:
    declared |= set(re.findall(r'@interface\s+(\w+)', open(path, encoding='utf-8').read()))

for path in LOGOS:
    text = open(path, encoding='utf-8').read()
    for match in re.finditer(r'^%hook\s+([\w.]+)', text, re.M):
        name = match.group(1)
        if '.' in name or name in declared:
            continue
        body = text[match.end():]
        end = body.find('\n%end')
        if re.search(r'\bself\.\w+', body[:end if end > 0 else len(body)]):
            report('%s hooked without an @interface but uses self.<property> in %s' % (name, path))

# 4. %orig sharing a line with braces or unbraced control flow.
#    This Logos version expands %orig with #line directives, which breaks such lines.
for path in LOGOS:
    for n, l in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        if '%orig' not in l or l.strip().startswith('//'):
            continue
        before = l.split('%orig')[0]
        if '{' in l or '}' in l or re.search(r'\b(if|else|for|while)\b[^;]*\)\s*$', before):
            report('fragile %%orig placement at %s:%d' % (path, n))

# 5. Unterminated string literals - Objective-C has no multi-line strings.
#    Comments must be stripped with string-awareness, or the "//" in every https://
#    URL truncates the line and every URL looks like an unterminated literal.
def strip_comment(line):
    in_string = False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_string:
            if ch == '\\':
                i += 2
                continue
            if ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch == '/' and i + 1 < len(line) and line[i + 1] == '/':
                return line[:i], in_string
        i += 1
    return line, in_string


for path in SRC + HDR:
    in_block_comment = False
    for n, l in enumerate(open(path, encoding='utf-8').read().splitlines(), 1):
        if in_block_comment:
            if '*/' in l:
                in_block_comment = False
            continue
        if l.strip().startswith('/*') and '*/' not in l:
            in_block_comment = True
            continue

        code, _ = strip_comment(l)
        if '"' not in code:
            continue
        # Drop escape sequences (\" \\ …) before counting quotes: an escaped quote
        # inside a regex pattern — @"\\b%@=\"([^\"]+)\"" — is not a string boundary,
        # and counting it as one flagged perfectly valid lines.
        if re.sub(r'\\.', '', code).count('"') % 2:
            report('unterminated string literal at %s:%d' % (path, n))

# 8. Project symbols used without the header that declares them.
#    A bulk rename introduced SCILogV across 36 files without checking imports;
#    the compiler only complained in the four that could not already see it.
SYMBOL_HEADERS = {
    'SCILogV': ('SCILog.h', 'Utils.h'),
    'SCIDiagnostics': ('SCIDiagnosticsViewController.h',),
    'SCIMediaDownloader': ('SCIMediaDownloader.h',),
    'SCILocalized': ('SCILocalize.h', 'Utils.h'),
}

HEADER_BY_NAME = {}
for path in HDR:
    HEADER_BY_NAME.setdefault(os.path.basename(path), path)


def reachable_headers(path, seen=None):
    """Every header a file can see, following imports transitively.

    Checking only direct imports produced nine false positives: the settings pages
    reach SCILocalize.h through TweakSettings.h -> Utils.h. A check that cries wolf
    gets ignored, so it has to resolve the whole chain.
    """
    if seen is None:
        seen = set()
    if path in seen:
        return set()
    seen.add(path)

    try:
        text = open(path, encoding='utf-8').read()
    except OSError:
        return set()

    names = set()
    for imp in re.findall(r'#import "([^"]+)"', text):
        base = os.path.basename(imp)
        names.add(base)
        target = HEADER_BY_NAME.get(base)
        if target:
            names |= reachable_headers(target, seen)

    return names


for path in SRC:
    text = open(path, encoding='utf-8').read()
    visible = reachable_headers(path)

    for symbol, headers in SYMBOL_HEADERS.items():
        if symbol not in text:
            continue
        if visible & set(headers):
            continue
        report('%s used in %s without importing %s' % (symbol, path, ' or '.join(headers)))

# 9. Quoted imports that resolve to nothing.
#
# Moving the sources one level deeper broke four files that reached the shared
# modules/ directory by counting "../" — a path that was correct only at the depth
# it was written. Nothing caught it: the count is still syntactically fine, and
# only the compiler knows the file is not there.
#
# A quoted import is resolved the way clang does: first beside the importing file,
# then against the include path. The include path is read out of the makefiles
# rather than assumed -- the first version of this rule hard-coded the repository
# root and immediately cried wolf over "dav1d/dav1d.h", which is perfectly valid
# and reachable through Instagram's own -Ivendor/dav1d/include.
def include_roots():
    roots = []
    for makefile in ('Makefile', '../../shared/tweak.mk'):
        if not os.path.isfile(makefile):
            continue
        text = open(makefile, encoding='utf-8').read()
        for flag in re.findall(r'-I(\S+)', text):
            roots.append(flag.replace('$(ROOT)', '../..'))
    return roots


INCLUDE_ROOTS = include_roots()

for path in SRC + HDR:
    here = os.path.dirname(path)
    for imported in re.findall(r'#import "([^"<>]+)"', open(path, encoding='utf-8').read()):
        candidates = [os.path.join(here, imported)]
        candidates += [os.path.join(root, imported) for root in INCLUDE_ROOTS]
        if not any(os.path.isfile(c) for c in candidates):
            report('%s imports "%s", which is not there' % (path, imported))

# 6. Localization parity and completeness.
#
# Reported rather than raised when the table is missing: a tweak with no
# bilingual table breaks a convention this project treats as a rule, and a
# traceback would say so far less clearly than a named failure.
LOC_PATH = 'src/Localization/SCILocalize.m'
loc = ''
en_keys, ar_keys, used = set(), set(), set()

if not os.path.isfile(LOC_PATH):
    # Reported rather than raised: a tweak with no bilingual table breaks a
    # convention this project treats as a rule, and a traceback would say so far
    # less clearly than a named failure among the others.
    report('no localization table at %s — every tweak here is bilingual' % LOC_PATH)
else:
    loc = open(LOC_PATH, encoding='utf-8').read()
    en = loc[loc.index('_enTable = @{'):loc.index('_arTable = @{')]
    ar = loc[loc.index('_arTable = @{'):]
    key_re = re.compile(r'@"([a-z0-9_]+)":\s*@"')
    en_keys, ar_keys = set(key_re.findall(en)), set(key_re.findall(ar))

    for key in sorted(en_keys ^ ar_keys):
        report('localization key present in only one table: %s' % key)

    for path in SRC + HDR:
        used |= set(re.findall(r'SCILocalized\(@"([a-z0-9_]+)"\)', open(path, encoding='utf-8').read()))

    for key in sorted(used - en_keys):
        report('localized key used but never defined: %s' % key)

# 6b. A stray quote inside a localized value.
#
# Rule 5 only catches an *odd* number of quotes. Writing
#     @"wn_u2_detail": @"Swap "2h" for a real date",
# leaves the count even, so it slipped through and broke the build at the point
# where Objective-C stopped reading the string.
#
# Counting quotes per line was the first attempt and cried wolf immediately —
# several entries legitimately put two pairs on one line. So instead: consume
# every well-formed @"..." literal, and require that what is left between them is
# only punctuation. A stray quote leaves prose behind, which nothing else does.
literal_re = re.compile(r'@"(?:[^"\\]|\\.)*"')

for number, line in enumerate(loc.splitlines(), 1):
    stripped = line.strip()
    if not stripped.startswith('@"') or '": @"' not in stripped:
        continue

    leftover = literal_re.sub('', stripped)
    if not re.fullmatch(r'[\s:,]*', leftover):
        report('unescaped quote inside a localized value at SCILocalize.m:%d — %s'
               % (number, stripped[:70]))

# 7. Version consistency across the files a release depends on.
#
# The version string is searched for across the sources rather than read from a
# fixed src/Tweak.x: each tweak names its entry point after itself, and pinning
# the filename here would mean the rule quietly stopped applying to the second
# one -- a version mismatch that reaches a release is the whole reason this rule
# exists.
control = open('control', encoding='utf-8').read()
control_version = re.search(r'^Version:\s*(\S+)', control, re.M).group(1)

version_re = re.compile(r'SCIVersionString\s*=\s*@"v?([^"]+)"')
declared = {}
for path in SRC + HDR:
    match = version_re.search(open(path, encoding='utf-8').read())
    if match:
        declared[path] = match.group(1)

if not declared:
    report('no SCIVersionString found in any source — nothing pins the build to control')
for path, version in sorted(declared.items()):
    if version != control_version:
        report('version mismatch: control=%s %s=%s' % (control_version, path, version))

print('keys: %d EN / %d AR   orphans: %d' % (len(en_keys), len(ar_keys), len(en_keys - used)))
print('version: %s' % control_version)
print()

if problems:
    for p in problems:
        print('FAIL  ' + p)
    raise SystemExit(1)

print('ALL CHECKS CLEAN')
