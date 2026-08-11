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
#
#    %group and %subclass close with %end too, and counting only %hook made the rule
#    report a broken file the moment the first group was written -- a false alarm, on
#    correct code, from a rule that had simply never seen valid syntax the project had
#    not used yet. Every opener is counted now.
#
#    The pairing still means something: an %end without an opener, or an opener left
#    unclosed, is the failure this catches, and both still fail.
for path in SRC:
    text = open(path, encoding='utf-8').read()
    hooks = len(re.findall(r'^%(hook|group|subclass)\b', text, re.M))
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

# 3. Hooked classes that touch self but have no @interface.
#
# Logos leaves a `%hook` on an undeclared class with only a forward declaration, and a
# `self` typed as a forward-declared class cannot be sent *any* message -- not even
# `-respondsToSelector:`, which is where the X inline button's build actually failed, on
# the guard rather than the property. So this catches a message send to self as well as
# `self.<property>`; the first version saw only the dot syntax and missed the button.
#
# @interface declarations are read from the sources too, not only the headers: the fix for
# that same failure declared the class inline in the .x, and a rule that looked only in
# headers would then have called the fixed file broken -- a false alarm on correct code,
# which is the way a check earns being ignored.
#
# System classes are skipped: a hooked NSFileManager or UIWindow gets its @interface from
# the SDK import, so `self` is fully typed and the send compiles. They are recognised by
# the Apple two-letter framework prefixes, none of which collide with this project's own
# (SCI, IG, T1/TFS/TFN/TAE/TAV/TPS/TUC/TUI, ML, YT).
declared = set()
for path in HDR + SRC:
    declared |= set(re.findall(r'@interface\s+(\w+)', open(path, encoding='utf-8').read()))

SYSTEM_PREFIX = re.compile(
    r'^(NS|UI|CA|CG|CF|AV|CL|WK|SK|MK|MP|PH|CM|CI|UN|CN|GLK|QL|EK|PK|HK|VN|NW|SF|WC)[A-Z]')

for path in LOGOS:
    text = open(path, encoding='utf-8').read()
    for match in re.finditer(r'^%hook\s+([\w.]+)', text, re.M):
        name = match.group(1)
        if '.' in name or name in declared or SYSTEM_PREFIX.match(name):
            continue
        body = text[match.end():]
        end = body.find('\n%end')
        body = body[:end if end > 0 else len(body)]
        if re.search(r'\bself\.\w+', body):
            report('%s hooked without an @interface but uses self.<property> in %s' % (name, path))
        elif re.search(r'\[\s*self\b', body):
            report('%s hooked without an @interface but sends a message to self in %s' % (name, path))

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
#
#    The macros and functions below are listed by hand because a header can offer
#    them under more than one name -- SCILogV arrives through Utils.h as readily as
#    through SCILog.h, and neither is wrong.
SYMBOL_HEADERS = {
    'SCILogV': ('SCILog.h', 'Utils.h'),
    'SCIDiagnostics': ('SCIDiagnosticsViewController.h',),
    'SCIMediaDownloader': ('SCIMediaDownloader.h',),
    'SCILocalized': ('SCILocalize.h', 'Utils.h'),
}

# Classes, by contrast, are found rather than listed.
#
# The hand-written table above covered four Instagram symbols and nothing else, so
# when a new class was used in a file that did not import its header, the check said
# nothing and the failure arrived five minutes into a CI compile -- which is the one
# thing this file exists to prevent. It happened to SCIYTStreamAPI in YouTube 0.7.0.
#
# Every @interface in the tweak's own headers is a symbol whose home is known exactly,
# so the map builds itself and a class added tomorrow is covered without an edit here.
# Only classes declared in exactly one header are included: a name in two places has no
# single answer to "which import is missing", and guessing would be a false positive.
_class_homes = collections.defaultdict(set)
for path in HDR:
    text = open(path, encoding='utf-8').read()
    for name in re.findall(r'^@interface\s+(\w+)', text, re.M):
        _class_homes[name].add(os.path.basename(path))

for name, homes in _class_homes.items():
    # Prefixed names only. A category on UIColor or NSString declares an @interface
    # too, and requiring an import for UIKit's own classes would cry wolf immediately.
    if len(homes) == 1 and name.startswith('SCI'):
        SYMBOL_HEADERS.setdefault(name, tuple(homes))

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
        # On a word boundary, not as a substring. Plain containment cried wolf the
        # moment classes were added to this table: SCIPhotoVideo is inside
        # SCIPhotoVideoSheet, and SCIWhatsNew inside SCIWhatsNewViewController, so four
        # files were accused of missing an import they did not need. A check that is
        # wrong four times out of four is one nobody reads again.
        if not re.search(r'\b%s\b' % re.escape(symbol), text):
            continue
        if visible & set(headers):
            continue
        report('%s used in %s without importing %s' % (symbol, path, ' or '.join(headers)))

# 10. A header promising a method the implementation does not define.
#
#     Two builds in a row died on this, both the same way: a script with several
#     asserts raised partway, so the header was written and the implementation was
#     not, and the gap only surfaced five minutes later as clang's
#     -Wincomplete-implementation. That is exactly the kind of failure this file
#     exists to move from minutes to seconds.
#
#     Only classes whose @interface and @implementation are both inside the tweak
#     are checked -- a category on a YouTube class declares methods the app defines,
#     and demanding those here would flag every header in the project.
_declared = collections.defaultdict(list)      # class -> [(kind, selector)]
_defined = collections.defaultdict(set)        # class -> {(kind, base)}

_method_re = re.compile(r'^\s*([+-])\s*\([^)]*\)\s*([A-Za-z_]\w*)', re.M)

for path in HDR:
    text = open(path, encoding='utf-8').read()

    # Split at each @interface so a method is attributed to the class above it, and
    # stop at @end so anything after it is not swept in.
    for match in re.finditer(r'@interface\s+(\w+)\s*(?::\s*\w+)?[^\n]*\n(.*?)@end',
                             text, re.S):
        name, body = match.group(1), match.group(2)

        # A category adds methods to a class defined elsewhere; its own @implementation
        # is not required to exist here.
        if re.match(r'@interface\s+\w+\s*\(', match.group(0)):
            continue

        for kind, base in _method_re.findall(body):
            _declared[name].append((kind, base))

for path in SRC:
    text = open(path, encoding='utf-8').read()
    for match in re.finditer(r'@implementation\s+(\w+)(.*?)@end', text, re.S):
        name, body = match.group(1), match.group(2)
        for kind, base in _method_re.findall(body):
            _defined[name].add((kind, base))

for name, methods in sorted(_declared.items()):
    # Nothing to compare against: the class is declared for another file's benefit,
    # which is how every YouTube and Instagram class in the headers is used.
    if name not in _defined:
        continue

    for kind, base in methods:
        if (kind, base) not in _defined[name]:
            report('%s declares %s%s but %s never defines it'
                   % (name, kind, base, name))

# 11. A block variable that calls itself.
#
#     ARC refuses this outright -- the block captures itself strongly and can never
#     be released -- so it is a build failure, not a leak. It is also the obvious way
#     to write "fetch these in order, one after the last finishes", which is how it
#     reached CI: `__block void (^next)(void)` ending in `next();`.
#
#     The usual workaround is a weak copy of the block, which trades the cycle for a
#     block that may be gone when the callback arrives. The fix that has neither
#     problem is a method calling itself, where the state is an argument rather than
#     a capture -- so this rule says to write one.
for path in SRC:
    text = open(path, encoding='utf-8').read()

    for match in re.finditer(r'__block\s+[\w\s*<>,]*\(\^(\w+)\)', text):
        name = match.group(1)

        # The body starts at the assignment that follows the declaration.
        assignment = re.search(r'\b%s\s*=\s*\^' % re.escape(name), text[match.end():])
        if not assignment:
            continue

        start = match.end() + assignment.end()
        depth = 1
        i = start
        while i < len(text) and depth:
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
            i += 1

        body = text[start:i]
        if re.search(r'\b%s\s*\(' % re.escape(name), body):
            report('block %s in %s calls itself — ARC rejects the retain cycle; '
                   'use a method that calls itself instead' % (name, path))

# 12. A method or property that collides with one UIKit already puts on the class.
#
#     Two builds died on this and the compiler's message names neither cause clearly.
#     A property called `close` on a view controller made -close its getter, and the
#     method of the same name was rejected for "returning the wrong type". A method
#     called -rename: resolved to UIResponder's -rename:, which is iOS 16 only, and
#     failed the availability check on a deployment target of 15.
#
#     Neither is findable by looking at the file: the colliding name is inherited, so
#     nothing in the source mentions it. That is exactly what a check is for.
#
#     The list is deliberately short -- the editing and responder-chain selectors a
#     feature is actually tempted to reuse. A long list of every UIKit selector would
#     fire on ordinary names and get switched off, which is worse than no rule.
UIKIT_TAKEN = {
    'rename:', 'close:', 'cut:', 'copy:', 'paste:', 'delete:', 'select:', 'selectAll:',
    'find:', 'print:', 'undo:', 'redo:', 'share:', 'duplicate:', 'move:', 'export:',
    'toggleBoldface:', 'increaseSize:', 'decreaseSize:', 'pasteAndMatchStyle:',
}

#     Scoped to the @implementation of a class that really is a UIKit subclass. The first
#     write of this rule scanned every declaration in any file that merely *contained* one,
#     and immediately cried wolf twice on the Instagram side -- a `title` on a presets
#     object, a `window` on a banner's owner, neither of them view controllers. That is the
#     same over-matching rule 8 was tightened for, made again.
for path in SRC:
    text = open(path, encoding='utf-8').read()

    header = path[:-2] + '.h' if path.endswith('.m') else None
    declarations = text
    if header and os.path.exists(header):
        declarations += open(header, encoding='utf-8').read()

    uikit = set(re.findall(r'@interface\s+(\w+)\s*:\s*UI\w+', declarations))
    if not uikit:
        continue

    for block in re.finditer(r'@implementation\s+(\w+)(.*?)@end', text, re.S):
        if block.group(1) not in uikit:
            continue

        for match in re.finditer(r'^-\s*\([^)]*\)\s*(\w+:)', block.group(2), re.M):
            selector = match.group(1)

            # Only the one-argument form. -share:from: is a different selector from
            # -share: and collides with nothing.
            after = block.group(2)[match.end():match.end() + 120]
            if re.match(r'\s*\([^)]*\)\s*\w+\s+\w+:', after):
                continue

            if selector in UIKIT_TAKEN:
                report('-%s in %s is a name UIKit already defines on this class — '
                       'rename it' % (selector, path))

#     And the other half of the same failure: a property whose name is also a method in the
#     same file. That one needs no knowledge of UIKit at all -- `close` as a property made
#     -close its getter, and the compiler rejected the real -close for returning void.
for path in SRC:
    text = open(path, encoding='utf-8').read()

    properties = set(re.findall(r'@property[^;]*?[\s*](\w+);', text))
    methods = set(re.findall(r'^-\s*\([^)]*\)\s*(\w+)\s*[{;]', text, re.M))

    for name in sorted(properties & methods):
        report('%s in %s is both a property and a method — the method becomes the '
               'property\'s getter and will not compile' % (name, path))

# 14. `self.property` inside a %group whose class is bound at load.
#
#     `%init(Group, Class = expr)` names the class at runtime, so Logos has nothing to type
#     `self` against and emits plain `id`. Dot syntax on `id` then fails to resolve, and the
#     error clang reports — "property 'view' not found on object of type
#     '__unsafe_unretained id const'" — points at the use rather than at the %init that
#     caused it, several hundred lines away in another part of the file.
#
#     This cost a CI build the first time twenty-five hooks were converted: three files
#     touched a property on self, and only the first of them got as far as being compiled.
#     The fix is a cast to the class's own declared type, which also restores the %property
#     accessors Logos adds.
#
#     Scoped to runtime-bound groups only. A group initialised plainly with %init(Group)
#     keeps its compile-time class and its dot syntax, and reporting those would be the
#     over-matching that rules 8 and 12 were both tightened for.
for path in SRC:
    text = open(path, encoding='utf-8').read()

    bound = set(re.findall(r'%init\(\s*(\w+)\s*,[^)]*=', text))
    if not bound:
        continue

    for block in re.finditer(r'^%group[ \t]+(\w+)[ \t]*$(.*?)^%end[ \t]*$', text, re.M | re.S):
        if block.group(1) not in bound:
            continue

        # A cast already in front of self is exactly the fix, so it is not a finding.
        body = re.sub(r'\(\s*\w+\s*\*\s*\)\s*self\b', 'CAST', block.group(2))

        for hit in sorted(set(re.findall(r'\bself\.(\w+)', body))):
            report('self.%s in group %s of %s — the group binds its class at load, so self '
                   'is id and dot syntax will not compile; cast self to its own type'
                   % (hit, block.group(1), path))

# 15. A plain C function shared with an Objective-C++ file, without extern "C".
#
#     .x compiles as Objective-C and .xm as Objective-C++, and C++ mangles a function name
#     by its argument types. So a .xm asks the linker for SCIResolveClass(NSString*) while
#     the .m that defines it exports plain _SCIResolveClass. Nothing complains until the
#     link, and then the error names every .xm that used it and not the header that needs
#     changing.
#
#     Methods are unaffected, which is why this took until the fifteenth rule to appear:
#     every other shared piece of this project is a class.
#
#     Only headers declaring a bare function are considered, and only when a .xm or .mm
#     actually imports them. A header used solely from .x files links perfectly well and
#     reporting it would be noise.
FUNCTION_DECL = re.compile(
    r'^\s*(?!static\b)(?!typedef\b)[A-Za-z_][\w \t*_]*?\b(\w+)\s*\([^;{]*\)\s*;', re.M)

cplusplus_users = set()
for path in SRC:
    if not path.endswith(('.xm', '.mm')):
        continue
    for quoted in re.findall(r'#import\s+"([^"]+)"', open(path, encoding='utf-8').read()):
        cplusplus_users.add(os.path.basename(quoted))

for path in HDR:
    if os.path.basename(path) not in cplusplus_users:
        continue

    text = open(path, encoding='utf-8').read()
    if 'extern "C"' in text:
        continue

    # Inside an @interface these are method declarations, not functions.
    outside = re.sub(r'@interface.*?@end', '', text, flags=re.S)

    for match in FUNCTION_DECL.finditer(outside):
        name = match.group(1)
        # A prototype has parentheses; a variable declaration does not reach here.
        if name in ('if', 'while', 'for', 'switch', 'return', 'sizeof'):
            continue
        report('%s in %s is a C function shared with an Objective-C++ file and the header '
               'has no extern "C" — the .xm will ask for a mangled name and fail at link'
               % (name, path))
        break

# 13. An untyped collection, subscripted for a property.
#
#     `NSDictionary *counts = [typed copy];` throws the element type away, so `counts[k]`
#     is `id`, and `id` has no -unsignedLongValue to find. It reads as ordinary code and
#     the mistake is in the *declaration*, several lines above the error the compiler
#     reports — which is why it went out in a commit and cost a build.
#
#     Not a wrong answer, only a failed compile. It is here because failing in a second
#     is the difference this file exists to make.
#
#     Only a bare declaration counts: with `NSDictionary<NSString *, NSNumber *> *` the
#     subscript is typed and there is nothing to report. Across both tweaks this fired
#     exactly once, on the line that caused it, and nowhere else.
UNTYPED_DECL = re.compile(r'\bNS(?:Mutable)?(?:Dictionary|Array)\s*\*\s*(\w+)\s*[=;]')

for path in SRC:
    untyped = set()

    for n, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        for match in UNTYPED_DECL.finditer(line):
            # A generic parameter sits between the class name and the star, so its
            # absence in that span is exactly what "bare" means.
            if '<' not in line[:match.start(1)].rsplit('NS', 1)[-1]:
                untyped.add(match.group(1))

        for name in untyped:
            if re.search(r'\b%s\[[^\]]+\]\.\w' % re.escape(name), line):
                report('%s at %s:%d is subscripted for a property but declared without '
                       'its element type — the subscript is id and will not compile'
                       % (name, path, n))

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

# 16. A local assigned and never mentioned again.
#
# The build runs with -Werror, so an unused local is a failed release rather than a
# warning. This one cost a CI run: one edit added `NSDictionary *fromFeatures = ...`
# and the second edit that was to use it silently matched nothing — the half-applied
# script this file already warns about twice, and none of the fifteen rules above
# could see it, because both halves are individually valid Objective-C.
#
# **The first version of this rule was wrong, and how is worth keeping.** Its pattern
# put a non-greedy `[\w\s*<>,]*?` before the capture, so it ate into the name itself:
# `NSString *page = ...` was reported as `age`, which then matched nothing else in the
# file and "failed". 180 findings across four tweaks that all compile clean. A rule
# that cries wolf gets ignored, which is why four of the rules above were tightened
# before landing and why this one was rewritten rather than shipped.
#
# So the name is taken as the last identifier before the `=` rather than by a pattern
# that has to guess where the type ends — and the other three tweaks are the oracle,
# since they build under -Werror today and any finding in them is a false positive.
LOCAL = re.compile(r'^\s{4,}([A-Za-z_][\w\s*<>,]*?)\s*=\s*[\[@]')
LAST_NAME = re.compile(r'([A-Za-z_]\w*)\s*\**$')

for path in SRC:
    body = open(path, encoding='utf-8').read()

    for n, line in enumerate(body.split(chr(10)), 1):
        stripped = line.strip()
        if stripped.startswith(('//', '*', '/*')):
            continue

        match = LOCAL.match(line)
        if not match:
            continue

        left = match.group(1)

        # A declaration is a type and a name. One identifier means an assignment to
        # something declared elsewhere — a static, an ivar, a property — and those are
        # written here and read from another function by design.
        if len(re.findall(r'[A-Za-z_]\w*', left)) < 2:
            continue

        name = LAST_NAME.search(left)
        if not name:
            continue
        name = name.group(1)

        # Every mention in the file, minus this declaration. The whole file rather than
        # the enclosing function, deliberately: a name used once more anywhere — in a
        # block, in another method, even in a comment — passes. That keeps the rule to
        # the mistake it was written for and leaves the compiler the stricter judge.
        if len(re.findall(r'\b%s\b' % re.escape(name), body)) > 1:
            continue

        report('%s at %s:%d is assigned and never used again — -Werror fails the build'
               % (name, path, n))

# 16b. A file-scope `static const` declared and never used.
#
# Rule 16 only sees indented locals; a `static const NSInteger SCILKSectionRecent = 2;`
# at column 0 is not a local and slipped past it into a -Werror stop on
# -Wunused-const-variable, one section constant that the code reached as a fall-through
# instead of by name. Different warning, same failure: the build stops and a CI run is
# spent on it.
#
# Narrow on purpose. Only `static const` at the start of a line, only when the name
# appears nowhere else in its file. A `static` that is written in one function and read
# in another is not const and is not matched; an `extern`/non-static const may be used
# from another file and is left to the compiler. The other four tweaks are the oracle —
# they build under -Werror, so a finding in them would be a false positive.
STATIC_CONST = re.compile(r'^static\s+const\s+[\w\s*<>]+?\b([A-Za-z_]\w*)\s*=')

for path in SRC:
    body = open(path, encoding='utf-8').read()

    for n, line in enumerate(body.split(chr(10)), 1):
        match = STATIC_CONST.match(line)
        if not match:
            continue

        name = match.group(1)
        if len(re.findall(r'\b%s\b' % re.escape(name), body)) > 1:
            continue

        report('%s at %s:%d is a static const never used — -Werror fails the build'
               % (name, path, n))

# 12. An SCI function called in this tweak that only exists in another one.
#
# `SCIPrefEnabled(...)` is the YouTube and Locket tweaks' helper. It was written into the
# Twitter tweak, whose Prefs.h has never had one, and the build died on the runner after
# every source in it had already compiled — a five-minute round trip for a symbol that is
# either present in the directory or is not.
#
# Five tweaks now share a file layout, a naming scheme and whole paragraphs of idiom, and
# they do *not* share their helpers. That makes borrowing one by muscle memory the obvious
# next mistake rather than a freak one, which is what earns a rule.
#
# Only `SCI…(` call shapes: a cast reads `(SCIYTJobKind)x` and a message send reads
# `[SCIYTMedia foo]`, so neither can be mistaken for a call. Definitions, declarations and
# function-like macros all count as present — the question is whether the compiler will
# find the name, not whether this file is where it lives.
SCI_CALL = re.compile(r'\b(SCI[A-Za-z0-9_]*)\s*\(')
SCI_DEFINED = re.compile(
    r'(?:^|\s)(?:#define\s+)?(SCI[A-Za-z0-9_]*)\s*\(')

known = set()
for path in SRC + HDR + glob.glob('../../shared/src/*.h') + glob.glob('../../shared/src/*.m'):
    try:
        body = open(path, encoding='utf-8').read()
    except OSError:
        continue

    for line in body.split(chr(10)):
        line = strip_comment(line)[0]

        # A definition or a declaration: either ends the line with `{` or `;` after the
        # parameter list, or is a #define. A call sits inside an expression, so requiring
        # the line to start with the return type keeps the two apart.
        if re.match(r'^\s*#define\s+SCI', line):
            # Object-like macros -- `#define SCIPrefHideAds @"hide_ads"` -- have no
            # parameter list and are not callable, so there is nothing to record. Asking
            # for group(1) on that returned None and took the whole run down; every tweak
            # has dozens of them.
            match = SCI_DEFINED.search(line)
            if match:
                known.add(match.group(1))
            continue

        match = re.match(r'^\s*(?:static\s+|inline\s+|extern\s+)*'
                         r'[A-Za-z_][\w\s*<>,]*?\b(SCI[A-Za-z0-9_]*)\s*\(', line)
        if match:
            known.add(match.group(1))

for path in SRC:
    for n, line in enumerate(open(path, encoding='utf-8').read().split(chr(10)), 1):
        line = strip_comment(line)[0]

        # An Objective-C directive is never a call, and `@interface SCIFoo ()` -- a class
        # extension, which every implementation file in this project opens with -- looks
        # exactly like one to the pattern. That was twenty-four false positives across four
        # tweaks on the first run of this rule, which is precisely how a check earns being
        # ignored. Skipped by the directive rather than by the parenthesis, so a category
        # `@interface SCIFoo (Bar)` goes with it.
        if re.match(r'^\s*@(interface|implementation|class|protocol|end)\b', line):
            continue

        for name in SCI_CALL.findall(line):
            if name in known:
                continue

            # A declaration of the thing itself is not a call to something missing.
            if re.match(r'^\s*(?:static\s+|inline\s+|extern\s+|void\s+|BOOL\s+|NSString)', line):
                continue

            report('%s at %s:%d is called but defined nowhere this tweak can see '
                   '-- another tweak has it' % (name, path, n))

print('keys: %d EN / %d AR   orphans: %d' % (len(en_keys), len(ar_keys), len(en_keys - used)))
print('version: %s' % control_version)
print()

if problems:
    for p in problems:
        print('FAIL  ' + p)
    raise SystemExit(1)

print('ALL CHECKS CLEAN')
