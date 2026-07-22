"""Pre-build checks for Albrhi.

Every rule here exists because that exact mistake reached CI at least once.
"""
import re
import glob
import collections
import os

SRC = (glob.glob('src/**/*.x', recursive=True)
       + glob.glob('src/**/*.xm', recursive=True)
       + glob.glob('src/**/*.m', recursive=True))
HDR = glob.glob('src/**/*.h', recursive=True)
LOGOS = [p for p in SRC if p.endswith(('.x', '.xm'))]

problems = []


def report(msg):
    problems.append(msg)


# 1. Duplicate @interface definitions.
for path in HDR:
    text = open(path, encoding='utf-8').read()
    for name, count in collections.Counter(re.findall(r'^@interface\s+(\w+)\s*:', text, re.M)).items():
        if count > 1:
            report('duplicate @interface %s x%d in %s' % (name, count, path))

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

# 6. Localization parity and completeness.
loc = open('src/Localization/SCILocalize.m', encoding='utf-8').read()
en = loc[loc.index('_enTable = @{'):loc.index('_arTable = @{')]
ar = loc[loc.index('_arTable = @{'):]
key_re = re.compile(r'@"([a-z0-9_]+)":\s*@"')
en_keys, ar_keys = set(key_re.findall(en)), set(key_re.findall(ar))

for key in sorted(en_keys ^ ar_keys):
    report('localization key present in only one table: %s' % key)

used = set()
for path in SRC + HDR:
    used |= set(re.findall(r'SCILocalized\(@"([a-z0-9_]+)"\)', open(path, encoding='utf-8').read()))

for key in sorted(used - en_keys):
    report('localized key used but never defined: %s' % key)

# 7. Version consistency across the files a release depends on.
control = open('control', encoding='utf-8').read()
control_version = re.search(r'^Version:\s*(\S+)', control, re.M).group(1)
tweak_version = re.search(r'SCIVersionString = @"v?([^"]+)"', open('src/Tweak.x', encoding='utf-8').read()).group(1)

if control_version != tweak_version:
    report('version mismatch: control=%s Tweak.x=%s' % (control_version, tweak_version))

print('keys: %d EN / %d AR   orphans: %d' % (len(en_keys), len(ar_keys), len(en_keys - used)))
print('version: %s' % control_version)
print()

if problems:
    for p in problems:
        print('FAIL  ' + p)
    raise SystemExit(1)

print('ALL CHECKS CLEAN')
