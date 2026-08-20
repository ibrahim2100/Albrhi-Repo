#import "SCIWUpdateProbe.h"
#import <objc/runtime.h>
#import <objc/message.h>

///
/// The classes worth asking about, and why each one is on the list.
///
/// Every name here was confirmed to exist in this iOS build before it was written down --
/// `SUBManager` and the `NR*` family from the Watch app's own import table, and
/// `COSSoftwareUpdateController` from `General.plist`, where the Watch app names it as the detail
/// controller for its Software Update row. **A name in a list nobody confirmed is how a report
/// comes back saying "absent" about a class that was never there to begin with**, which reads as
/// a finding and is only a typo.
///
static NSArray<NSString *> *SCIWProbeSubjects(void) {
    return @[
        // The update path, on the phone side.
        @"SUBManager",
        @"COSSoftwareUpdateController",
        @"COSSoftwareUpdateAutomaticUpdateContoller",   // Apple's own spelling, kept verbatim

        // Pairing, already hooked -- probed so a report says whether the build this tweak is
        // running on matches the one its hooks were written against.
        @"NRPairingCompatibilityVersionInfo",
        @"NRDevice",
        @"NRPairedDeviceRegistry",

        // The sync subsystems, for the features that come next. Nothing hooks these yet; the
        // report is what decides whether anything can.
        @"NPSManager",
        @"NPSDomainAccessor",
    ];
}

/// Selectors worth reporting in full, because a hook is being considered for them.
static NSArray<NSString *> *SCIWProbeSelectorsFor(NSString *className) {
    if ([className isEqualToString:@"SUBManager"]) {
        return @[@"scanForUpdates", @"checkForSoftwareUpdate:",
                 @"managerUserDidAcceptTermsAndConditionsForUpdate:", @"humanReadableUpdateName"];
    }
    return @[];
}

///
/// Classes whose **whole** method list is worth printing, and how to keep it readable.
///
/// A name and a count answer "is it here"; they cannot answer "what do I hook". `SUBManager` came
/// back with 33 methods and the one selector this tweak had guessed at was not among them --
/// which is this project's oldest lesson (a selector dump names what exists, class metadata names
/// who answers it) arriving from the one direction it had not yet: the class was right, the
/// method list was never asked for.
///
/// A filter comes with it because `COSSoftwareUpdateController` has 161 methods and a report
/// nobody can read is not a report. An empty filter means everything -- written deliberately,
/// because a filter loop that only adds from inside itself returns nothing when asked for
/// "everything", which this project has already shipped once.
///
static NSArray<NSString *> *SCIWProbeFilterFor(NSString *className) {
    if ([className isEqualToString:@"SUBManager"]) return @[];              // all 33
    if ([className isEqualToString:@"COSSoftwareUpdateAutomaticUpdateContoller"]) return @[];  // 8

    // NanoPreferencesSync, in full: 17 and 54 methods, and **this is the route the four sync
    // features have to be written from**. It is the phone's own way of pushing a preference domain
    // to the watch -- present in SpringBoard, where this tweak already runs and already works --
    // and it needs no IDS, no injection into a system app, and nothing installed on the watch.
    // Counts told us the classes are here; only the lists can say what to call.
    // The paired-device registry, filtered. `NPSDomainAccessor` also takes `-initWithDomain:
    // pairedDevice:`, and an accessor built without one may be bound to nothing -- which is the
    // reading the first domain probe's uniform zeroes point at. This is where the device comes
    // from, and its 127 methods are worth exactly the ones that name a device.
    if ([className isEqualToString:@"NRPairedDeviceRegistry"]) {
        return @[@"active", @"paired", @"default", @"shared", @"current"];
    }

    if ([className isEqualToString:@"NPSManager"]) return @[];
    if ([className isEqualToString:@"NPSDomainAccessor"]) return @[];

    if ([className isEqualToString:@"COSSoftwareUpdateController"]) {
        return @[@"update", @"scan", @"check", @"avail", @"download", @"install",
                 @"eligib", @"version", @"defer", @"enabl"];
    }
    return nil;   // nil means: do not dump this class at all
}

static NSString *SCIWDumpMethods(NSString *name) {
    NSArray<NSString *> *filter = SCIWProbeFilterFor(name);
    if (!filter) return nil;

    Class cls = NSClassFromString(name);
    if (!cls) return nil;

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    if (!methods) return nil;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        NSString *selector = NSStringFromSelector(method_getName(methods[i]));

        if (filter.count) {
            BOOL wanted = NO;
            for (NSString *needle in filter) {
                if ([selector rangeOfString:needle
                                    options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    wanted = YES;
                    break;
                }
            }
            if (!wanted) continue;
        }

        const char *types = method_getTypeEncoding(methods[i]);
        [lines addObject:[NSString stringWithFormat:@"    -%@ %s", selector,
                          types ?: "no encoding"]];
    }
    free(methods);

    if (!lines.count) return nil;

    [lines sortUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"%@ — %@ of %u method(s):\n%@",
            name, filter.count ? @"matching" : @"all", count,
            [lines componentsJoinedByString:@"\n"]];
}

static NSString *sciwProbeReport = nil;

///
/// One class: is it here, how many methods, and what do the interesting ones really look like.
///
/// `class_copyMethodList` answers about the class itself; a selector inherited from a superclass
/// would be missed by that alone, so `class_getInstanceMethod` is asked separately for the ones a
/// hook is being written against -- it walks the chain, which is what `%hook` will do too.
///
static NSString *SCIWDescribeClass(NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) return [NSString stringWithFormat:@"%@: ABSENT", name];

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    if (methods) free(methods);

    NSMutableString *line = [NSMutableString stringWithFormat:@"%@: present, %u method(s)",
                             name, count];

    for (NSString *selectorName in SCIWProbeSelectorsFor(name)) {
        SEL selector = NSSelectorFromString(selectorName);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) {
            [line appendFormat:@"; -%@ MISSING", selectorName];
            continue;
        }

        const char *types = method_getTypeEncoding(method);
        // The encoding, verbatim. This is the whole reason the probe exists: it is what a hook
        // has to declare, and the only place it can be read from without guessing.
        [line appendFormat:@"; -%@ %s", selectorName, types ?: "no encoding"];
    }

    return line;
}

void SCIWRunUpdateProbe(void) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"in %@",
        [[NSBundle mainBundle] bundleIdentifier] ?: @"?"]];

    for (NSString *name in SCIWProbeSubjects()) {
        [lines addObject:SCIWDescribeClass(name)];
    }

    // The full lists, after the summary rather than inside it: the summary is what a person reads
    // and these are what the next hook is written from.
    for (NSString *name in SCIWProbeSubjects()) {
        NSString *dump = SCIWDumpMethods(name);
        if (dump) [lines addObject:[@"\n" stringByAppendingString:dump]];
    }

    sciwProbeReport = [lines componentsJoinedByString:@"\n"];

    // Written where Settings can read it: the probe runs inside SpringBoard and the Watch app,
    // and the page that shows it runs inside Settings. A value that never leaves the process
    // that produced it is a diagnostic nobody can send.
    // **One key per process.** Both processes ran this and both wrote the same key, so whichever
    // launched last was the only one ever read -- two reports, one slot, and the section that
    // mattered was always the missing one.
    NSString *key = [@"watch_probe_report_" stringByAppendingString:
                        [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown"];
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)sciwProbeReport,
                             CFSTR("com.albrhi.watch"));
    CFPreferencesAppSynchronize(CFSTR("com.albrhi.watch"));
}

NSString *SCIWUpdateProbeReport(void) {
    return sciwProbeReport ?: @"the probe has not run in this process yet";
}
