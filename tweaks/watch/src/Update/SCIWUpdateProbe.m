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
