#import "SCIResolve.h"
#import "../SCILog.h"
#import <objc/runtime.h>

///
/// One scan of the loaded classes, kept.
///
/// Instagram 441 has 38,468 classes. Walking them costs a few milliseconds once and is worth
/// paying at load rather than per lookup: the alternative is every hook paying it, and the
/// hooks all run inside +load and %ctor where the app is already waiting.
///
/// Only Swift class names go in the index. A class whose runtime name is its plain name is
/// found by objc_getClass without any of this.
///

/// plain class name -> Swift runtime name
static NSMutableDictionary<NSString *, NSString *> *sciSwiftIndex = nil;

/// what was asked for -> what was found ("" for nothing)
static NSMutableDictionary<NSString *, NSString *> *sciAnswers = nil;

/// Made on first use rather than inside SCIBuildIndex, which the plain-name and hint paths
/// deliberately never reach. Writing into a nil dictionary is a silent no-op in
/// Objective-C, so leaving it there would have cost the diagnostics every resolution that
/// actually succeeded and kept only the ones that had to search.
static NSMutableDictionary<NSString *, NSString *> *SCIAnswers(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sciAnswers = [NSMutableDictionary dictionary]; });
    return sciAnswers;
}

/// Decodes `_TtC<len><Module><len><Class>` and hands back the class half.
///
/// Written against the shape rather than against a demangler: this is the one nesting the
/// project needs, the numbers are plain decimal lengths, and a wrong read produces nil
/// rather than a wrong name.
static NSString *SCISwiftClassName(const char *runtimeName) {
    if (strncmp(runtimeName, "_TtC", 4) != 0) return nil;

    const char *cursor = runtimeName + 4;

    // Two length-prefixed components: the module, then the class.
    for (int part = 0; part < 2; part++) {
        if (*cursor < '0' || *cursor > '9') return nil;

        NSInteger length = 0;
        while (*cursor >= '0' && *cursor <= '9') {
            length = length * 10 + (*cursor - '0');
            cursor++;
        }
        if (length <= 0 || strlen(cursor) < (size_t)length) return nil;

        if (part == 1) {
            // The class name must be the whole of what is left. A trailing component means
            // a nested type, and a nested type of the same name is not the same class.
            if (strlen(cursor) != (size_t)length) return nil;
            return [[NSString alloc] initWithBytes:cursor
                                            length:length
                                          encoding:NSUTF8StringEncoding];
        }
        cursor += length;
    }
    return nil;
}

static void SCIBuildIndex(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sciSwiftIndex = [NSMutableDictionary dictionary];

        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        if (!classes) return;

        NSUInteger swift = 0;
        for (unsigned int i = 0; i < count; i++) {
            const char *runtimeName = class_getName(classes[i]);
            if (!runtimeName) continue;

            NSString *plain = SCISwiftClassName(runtimeName);
            if (!plain.length) continue;

            // First writer wins, and a second is recorded rather than overwritten. Two
            // modules can define a class of the same name -- IGExploreListKitDataSource is
            // one -- and silently picking either would be the guessing this file exists to
            // avoid. The caller gets the first and the log names the collision.
            if (sciSwiftIndex[plain]) {
                SCILogV(@"[resolve] %@ is defined by more than one Swift module", plain);
                continue;
            }
            sciSwiftIndex[plain] = @(runtimeName);
            swift++;
        }
        free(classes);

        SCILogV(@"[resolve] indexed %lu Swift classes of %u loaded",
                (unsigned long)swift, count);
    });
}

Class SCIResolveClass(NSString *name) {
    return SCIResolveClassWithHint(name, nil);
}

Class SCIResolveClassWithHint(NSString *name, NSString *runtimeName) {
    if (!name.length) return nil;

    // 1. The plain name. On 410 every one of these resolves here and nothing else runs,
    //    which is what keeps the older build's behaviour byte-for-byte what it was.
    Class direct = objc_getClass(name.UTF8String);
    if (direct) {
        @synchronized (SCIAnswers()) { SCIAnswers()[name] = name; }
        return direct;
    }

    // 2. The runtime name the caller already knew. Deliberately before the search and
    //    before the index is ever built: this is the lookup the code did before this file
    //    existed, it worked, and replacing it with a search broke the reels download
    //    button on 439 and 441. A hint that still matches must never be beaten by a
    //    search that might not.
    if (runtimeName.length) {
        Class hinted = objc_getClass(runtimeName.UTF8String);
        if (hinted) {
            @synchronized (SCIAnswers()) { SCIAnswers()[name] = runtimeName; }
            SCILogV(@"[resolve] %@ -> %@ (hint)", name, runtimeName);
            return hinted;
        }
        SCILogV(@"[resolve] %@: the known name %@ no longer matches; searching",
                name, runtimeName);
    }

    // 3. And only now the search, for the build where the module moved.
    SCIBuildIndex();

    NSString *mangled = nil;
    @synchronized (sciSwiftIndex) { mangled = sciSwiftIndex[name]; }

    Class found = mangled ? objc_getClass(mangled.UTF8String) : Nil;

    @synchronized (SCIAnswers()) { SCIAnswers()[name] = found ? mangled : @""; }

    if (found) {
        SCILogV(@"[resolve] %@ -> %@ (found)", name, mangled);
    } else {
        SCILogV(@"[resolve] %@ is not in this build under any name", name);
    }
    return found;
}

NSString *SCIResolvedNameFor(NSString *name) {
    if (!name.length) return nil;
    @synchronized (SCIAnswers()) { return SCIAnswers()[name]; }
}
