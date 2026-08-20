#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCIWUpdateGuard.h"
#import "../Prefs.h"
#import "../Diagnostics/SCIWDiagnostics.h"
#import "../Localization/SCILocalize.h"
#import "../Bridge/SCIWBridgeSignal.h"

///
/// Holding a watchOS update back, inside the Watch app — written from a device's own method lists.
///
/// **Where this came from, and where it did not.** Reading a commercial tweak's package told us one
/// thing worth knowing and it was a negative: its update feature hooks nothing on the phone at all,
/// it speaks to the watch over IDS. What *is* on the phone is `SUBManager` from
/// `SoftwareUpdateBridge` and `COSSoftwareUpdateController`, which the Watch app's own
/// `General.plist` names as its Software Update page. Those two facts are the entire basis here;
/// no logic was taken from anybody.
///
/// **Refusing `-scanForUpdates` was wrong, and the method list is what showed it.** The scan is
/// asynchronous: its answer comes back through the delegate, and the page tracks the wait in
/// `-isExpectingScanResult` / `-hasReceivedValidFirstScanResult`. Swallow the *call* and no answer
/// ever arrives — the page waits forever, which is a spinner that never stops, not a phone that is
/// up to date. This project has shipped that mistake in another shape already: a principle applied
/// at the wrong point removes the working behaviour instead of the unwanted one.
///
/// **So the answer is replaced rather than the question refused**, which is also how the TikTok ad
/// filter works: let the app do its work, then hand back the result it would get if there were
/// nothing to find. `-manager:scanRequestDidLocateUpdate:error:` is the delegate callback that
/// carries a located update, confirmed on-device as `v40@0:8@16@24@32`, and `%orig` with a nil
/// update is exactly the shape of Apple's own "nothing found" path — the page has
/// `-noUpdateFoundOrIsComplete` for precisely that state.
///
/// **And the download and the install are refused as well**, because one intercepted answer is a
/// single point of failure for something irreversible. `-startDownload:` and `-installUpdate:` are
/// where an update stops being a notice and starts being a change to the watch.
///
/// **Every hook is installed only if the runtime encoding matches what it was compiled against.**
/// `class_getInstanceMethod` returning non-NULL proves a selector exists and says nothing about its
/// types; a `%hook` with wrong argument types does not fail politely. This project crashed one app
/// four times learning that.
///

@interface SUBManager : NSObject
@end

@interface COSSoftwareUpdateController : NSObject
@end

/// Preferences' own row object. Declared rather than imported: this tweak does not link
/// Preferences.framework, and the four selectors used here are the whole of what it needs.
@interface PSSpecifier : NSObject
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (NSString *)name;
- (NSString *)identifier;
@end

static NSString *sciwGuardState = nil;
static NSString *sciwUpdateShape = nil;
static NSString *sciwHeldVersion = nil;
static NSString *sciwPassedVersion = nil;
static NSString *sciwPageShape = nil;
static NSUInteger sciwPageStamps = 0;

///
/// **One counter answered "no" for five different reasons, which is a count and not a diagnosis.**
///
/// `the page was stamped 0 time(s)` is true whether the hook never fired, the controller does not
/// answer `-specifiers`, the list came back empty because the rows are not built yet, or the list
/// was fine and no row carried a footer to stamp. This project already knows the shape of that
/// mistake -- the quality picker was fixed three times against the wrong stage until it reported
/// `raw -> parsed -> deduped` separately -- so each stage counts itself.
///
static NSUInteger sciwStampCalls = 0;      ///< the hook fired
static NSUInteger sciwStampAsked = 0;      ///< the controller answered -specifiers
static NSUInteger sciwStampRows = 0;       ///< rows in the last list seen
static NSUInteger sciwStampFooters = 0;    ///< rows carrying footer text
static NSString *sciwStampStop = nil;      ///< where the last attempt gave up

///
/// **The report is written at launch, and everything interesting happens afterwards.**
///
/// `stamp: 0 call(s)` was read as "the hooks never fired" and it was not: the drop that carries
/// the report is written from `%ctor`, before any page can have appeared, so the counters in it
/// are always the counters of a process that has just started. A report with no timestamp and no
/// refresh describes one instant and is read as describing the run — which is this project's own
/// tally-versus-snapshot rule, arriving in the diagnostic rather than in the feature.
///
/// So the drop is rewritten after anything worth reporting. It is a few kilobytes to the app's own
/// container, and SpringBoard picks it up on the notification that follows.
///
static void SCIWRefreshReport(void) {
    static NSDate *last = nil;

    // Throttled, because a redrawing table can call this several times a second and a diagnostic
    // has no business being the most frequent writer in the process.
    if (last && [[NSDate date] timeIntervalSinceDate:last] < 2.0) return;
    last = [NSDate date];

    SCIWBridgeAnnounce();
}

/// The encodings, every one read off the device by the probe beside this file.
static NSString *const kSCIWScanResultEncoding = @"v40@0:8@16@24@32";  // -manager:scanRequestDidLocateUpdate:error:
static NSString *const kSCIWDownloadEncoding = @"v24@0:8@16";          // -startDownload:
static NSString *const kSCIWDownloadPasscodeEncoding = @"v32@0:8@16@24";
static NSString *const kSCIWInstallEncoding = @"v24@0:8@16";           // -installUpdate:
static NSString *const kSCIWInstallPasscodeEncoding = @"v32@0:8@16@24";

///
/// What the located update actually is, recorded the one time it exists.
///
/// **The version filter cannot be written until this comes back.** The switch is asked for as "stop
/// watchOS 26", and a hold that refuses every update is not that -- but the descriptor's class and
/// accessors are not in any header this machine has, and guessing at them is the mistake this whole
/// tweak has been correcting for four releases. So the first update this ever sees is described
/// into the report, behind `-respondsToSelector:` at every step, and the next release filters on a
/// name a device confirmed.
///
static void SCIWDescribeUpdate(id update) {
    if (!update || sciwUpdateShape.length) return;

    NSMutableString *shape = [NSMutableString stringWithFormat:@"%@",
                              NSStringFromClass([update class])];

    for (NSString *name in @[@"humanReadableUpdateName", @"productVersion", @"osVersion",
                             @"version", @"build", @"productBuildVersion", @"detailedDescription",
                             @"downloadSize", @"isCritical", @"updateName"]) {
        SEL selector = NSSelectorFromString(name);
        if (![update respondsToSelector:selector]) continue;

        // Only object-returning accessors are sent. A scalar read through the wrong cast is the
        // fault this file's own header warns about, and a shape report is not worth a crash.
        Method method = class_getInstanceMethod([update class], selector);
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        if (!types || types[0] != '@') {
            [shape appendFormat:@"; -%@ %s (not read)", name, types ?: "?"];
            continue;
        }

        id value = ((id (*)(id, SEL))objc_msgSend)(update, selector);
        [shape appendFormat:@"; -%@ = %@", name, value];
    }

    sciwUpdateShape = shape;
}

///
/// Says on the page itself that Albrhi is the reason it shows nothing.
///
/// **Withholding an update makes iOS tell its owner the watch is up to date, which is a sentence
/// this tweak caused and iOS believes.** That is worse than the thing being hidden: a person
/// reading "up to date with all the latest security enhancements" has been given a fact about
/// their watch, not a consequence of their own setting. So the page says who withheld it.
///
/// **The footer is edited, not replaced from a rebuilt list.** `-reloadSpecifiers` asks the
/// controller to build its rows again, which would discard this edit the moment it is made;
/// `-reloadSpecifier:` redraws the one row from the object already in the list. Both are guarded,
/// like every private selector here.
///
/// And the whole specifier list is recorded the first time, so a later release can name Apple's
/// own footer precisely instead of taking the last one carrying text — which is a heuristic, and
/// is described as one in the report rather than trusted quietly.
///
static void SCIWStampUpdatePage(id controller) {
    sciwStampCalls++;

    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        sciwStampStop = @"the hold is switched off";
        SCIWRefreshReport();
        return;
    }
    if (![controller respondsToSelector:@selector(specifiers)]) {
        sciwStampStop = [NSString stringWithFormat:@"%@ does not answer -specifiers",
                         NSStringFromClass([controller class])];
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSArray *specifiers = ((id (*)(id, SEL))objc_msgSend)(controller,
                                                              @selector(specifiers));
        sciwStampAsked++;

        if (![specifiers isKindOfClass:[NSArray class]] || !specifiers.count) {
            // The rows are built when the page loads, not when the delegate answers -- so an
            // empty list here is a timing answer, and it is worth saying which.
            sciwStampStop = [NSString stringWithFormat:@"-specifiers gave %@",
                             specifiers ? @"an empty list" : @"nothing"];
            return;
        }
        sciwStampRows = specifiers.count;

        NSMutableArray<NSString *> *shape = [NSMutableArray array];
        PSSpecifier *target = nil;

        for (PSSpecifier *specifier in specifiers) {
            if (![specifier respondsToSelector:@selector(propertyForKey:)]) continue;

            id footer = [specifier propertyForKey:@"footerText"];
            NSString *footerText = [footer isKindOfClass:[NSString class]] ? footer : nil;

            [shape addObject:[NSString stringWithFormat:@"    %@ / %@%@",
                [specifier respondsToSelector:@selector(name)] ? ([specifier name] ?: @"—") : @"?",
                [specifier respondsToSelector:@selector(identifier)]
                    ? ([specifier identifier] ?: @"—") : @"?",
                footerText.length ? [@" — footer: " stringByAppendingString:footerText] : @""]];

            // The last row carrying a footer: on this page that is the one under the version,
            // which is the sentence a person actually reads.
            if (footerText.length) {
                sciwStampFooters++;
                target = specifier;
            }
        }

        if (!sciwPageShape) sciwPageShape = [shape componentsJoinedByString:@"\n"];

        if (!target) {
            sciwStampStop = @"no row on this page carries footer text";
        SCIWRefreshReport();
            return;
        }

        NSString *existing = [target propertyForKey:@"footerText"] ?: @"";

        // **Idempotent by content, not by a flag.** Leaving the page and returning rebuilds the
        // rows, so a one-shot stamp is applied once and then silently absent for the rest of the
        // launch -- while that same one-shot would double the text on a row that was not rebuilt.
        // Asking whether the notice is already there answers both.
        if ([existing containsString:SCILocalized(@"hold_notice")]) {
            sciwStampStop = @"already stamped";
        SCIWRefreshReport();
            return;
        }
        [target setProperty:[NSString stringWithFormat:@"%@\n\n%@",
                                SCILocalized(@"hold_notice"), existing]
                     forKey:@"footerText"];

        if ([controller respondsToSelector:@selector(reloadSpecifier:)]) {
            ((void (*)(id, SEL, id))objc_msgSend)(controller, @selector(reloadSpecifier:), target);
        }

        sciwPageStamps++;
        SCIWRecordAnswer(@"update page stamped");
        SCIWRefreshReport();
    });
}

///
/// **"Stop watchOS 26" is now a thing this code can actually say.**
///
/// The device named the descriptor and its accessors: `SUBDescriptor`, with
/// `-humanReadableUpdateName = watchOS 26.6`, `-productVersion = 26.6` and
/// `-productBuildVersion = 23U67`. Until that came back the hold was necessarily coarse -- it
/// withheld every update, which is not what was asked for and was described as not being it.
///
/// The comparison is on the **major** number alone. `26.6`, `26.0.1` and `26` all answer 26, and a
/// string compare would order `26.6` before `9.5`; this project has already paid for a comparison
/// that ranked the wrong thing correctly.
///
/// An update whose version cannot be read is **let through**, not held. A hold that fires when it
/// cannot tell what it is holding is the coarse behaviour again wearing a filter's name, and the
/// irreversible direction here is the one that stops a security update.
///
static NSInteger SCIWMajorVersion(id update) {
    if (![update respondsToSelector:@selector(productVersion)]) return 0;

    id version = ((id (*)(id, SEL))objc_msgSend)(update, @selector(productVersion));
    if (![version isKindOfClass:[NSString class]]) return 0;

    NSString *major = [(NSString *)version componentsSeparatedByString:@"."].firstObject;
    return major.length ? major.integerValue : 0;
}

static BOOL SCIWShouldHold(id update) {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) return NO;
    if (!update) return NO;

    NSInteger major = SCIWMajorVersion(update);
    NSInteger floor = SCIWReadInteger(SCIWPrefHoldFromMajor, 26);

    id name = [update respondsToSelector:@selector(humanReadableUpdateName)]
        ? ((id (*)(id, SEL))objc_msgSend)(update, @selector(humanReadableUpdateName)) : nil;
    NSString *label = [NSString stringWithFormat:@"%@ (major %ld)", name ?: @"unnamed", (long)major];

    if (major && major >= floor) {
        sciwHeldVersion = label;
        return YES;
    }

    // Said out loud rather than silently allowed: "it let one through" and "it never saw one" are
    // the two things a report has to separate, and only one of them is a bug.
    sciwPassedVersion = [NSString stringWithFormat:@"%@ — allowed, the hold starts at %ld",
                         label, (long)floor];
    return NO;
}

/// Why a selector was skipped, in the words the next release gets written from.
static NSString *SCIWDescribeSelector(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return [NSString stringWithFormat:@"-%@ is not on this class", selectorName];

    const char *types = method_getTypeEncoding(method);
    return [NSString stringWithFormat:@"-%@ is %s (expected %@)",
            selectorName, types ?: "no encoding", expected];
}

static BOOL SCIWEncodingMatches(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    return types && [expected isEqualToString:[NSString stringWithUTF8String:types]];
}

///
/// The state, carried out of this process by the file drop rather than by a preference.
///
/// A preference written here is redirected into this app's own container -- established on a
/// device, not assumed -- so the verdict rides in the report instead. This write stays because it
/// costs nothing and is correct wherever the sandbox permits it.
///
static void SCIWPublishGuardState(void) {
    if (!sciwGuardState.length) return;
    CFPreferencesSetAppValue(CFSTR("watch_update_guard"),
                             (__bridge CFPropertyListRef)sciwGuardState, SCIWDomain);
    CFPreferencesAppSynchronize(SCIWDomain);
}

//
// One group per selector. A `%hook` on a method a class does not declare does not politely do
// nothing -- Logos adds it -- so a build missing one of these must skip it rather than invent it.
// The device already proved that matters: `-checkForSoftwareUpdate:` is not on `SUBManager` here.
//

%group ScanResult

%hook COSSoftwareUpdateController

- (void)manager:(id)manager scanRequestDidLocateUpdate:(id)update error:(id)error {
    if (!SCIWShouldHold(update)) {
        %orig;
        return;
    }

    // Described before it is dropped: this is the only moment the object exists, and the version
    // filter that turns "hold everything" into "hold 26" is written from what this reports.
    SCIWDescribeUpdate(update);
    SCIWRecordAnswer(@"update withheld at the scan result");

    // The page's own "nothing found" state, reached the way the page reaches it: no update, no
    // error. Refusing the scan itself would leave it waiting for an answer that never came.
    %orig(manager, nil, error);

    //
    // **Handing the page a nil update is not the same as telling it nothing was found.**
    //
    // A device reported the result plainly: the page sat on "Checking for updates…" forever. The
    // wait is not inferred from the argument -- the page keeps it in its own flags, and this class
    // declares every one of them as a setter (`v20@0:8B16`, read off the device). So the state is
    // settled explicitly rather than hoped for, which is the same lesson as `-bypassOnesie` in the
    // YouTube tweak: code that keeps its own copy is never reached by answering a getter.
    //
    for (NSString *name in @[@"setIsExpectingScanResult:", @"setNoUpdateFoundOrIsComplete:",
                             @"setHasReceivedValidFirstScanResult:"]) {
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod([self class], selector);
        if (!method || strcmp(method_getTypeEncoding(method), "v20@0:8B16") != 0) continue;

        BOOL value = ![name isEqualToString:@"setIsExpectingScanResult:"];
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, selector, value);
    }

    SCIWRecordAnswer(@"scan state settled to 'no update'");
    SCIWRefreshReport();
    SCIWStampUpdatePage(self);
}

%end
%end

//
// **The stamp cannot wait for an update to be located.** `-manager:scanRequestDidLocateUpdate:`
// fires only when a scan finds something, and once the hold has answered once the app may not ask
// again for the rest of a launch -- so the page said the watch was up to date with nothing to say
// who decided that. A device reported exactly that: every hook installed, and no page shape in the
// report, because the callback had never run.
//
// These two are the page's own signals: `-startSUBUpdates` is it going live and
// `-updateTableViewWithTask:` is it redrawing. Both are declared on the class, both encodings read
// off the device.
//
//
// **Withholding the scan result was not enough, and the page said so itself.** With every hook
// installed and `watchOS 26.6` recorded as seen, the report's own dump of the page still listed
// `INSTALL_BUTTON_GROUP` and a `Download and Install` row. So the descriptor reaches the page by
// more than one road: the controller keeps it in `-setUpdate:` and is driven by
// `-handleManagerState:update:error:`, both declared here, both encodings read off the device.
//
// This is the shape of the watermark fix in the TikTok tweak: a value that is *stored* is true for
// every reader afterwards, while intercepting one delivery only answers one caller.
//
%group SetUpdate

%hook COSSoftwareUpdateController

- (void)setUpdate:(id)update {
    if (SCIWShouldHold(update)) {
        SCIWDescribeUpdate(update);
        SCIWRecordAnswer(@"held update refused at -setUpdate:");
        %orig(nil);
        SCIWRefreshReport();
        return;
    }
    %orig;
}

%end
%end

%group ManagerState

%hook COSSoftwareUpdateController

- (void)handleManagerState:(long long)state update:(id)update error:(id)error {
    if (SCIWShouldHold(update)) {
        SCIWDescribeUpdate(update);
        SCIWRecordAnswer(@"held update removed from the state handler");
        %orig(state, nil, error);
        SCIWRefreshReport();
        return;
    }
    %orig;
}

%end
%end

%group PageAppears

%hook COSSoftwareUpdateController

- (void)startSUBUpdates {
    %orig;
    SCIWStampUpdatePage(self);
}

%end
%end

%group PageRedraws

%hook COSSoftwareUpdateController

- (void)updateTableViewWithTask:(id)task {
    %orig;
    SCIWStampUpdatePage(self);
}

%end
%end

%group DownloadStart

%hook SUBManager

- (void)startDownload:(id)update {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        %orig;
        return;
    }
    SCIWDescribeUpdate(update);
    SCIWRecordAnswer(@"update download refused");
}

%end
%end

%group DownloadStartPasscode

%hook SUBManager

- (void)startDownload:(id)update passcode:(id)passcode {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        %orig;
        return;
    }
    SCIWRecordAnswer(@"update download refused (passcode)");
}

%end
%end

%group InstallUpdate

%hook SUBManager

- (void)installUpdate:(id)update {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        %orig;
        return;
    }
    SCIWDescribeUpdate(update);
    SCIWRecordAnswer(@"update install refused");
}

%end
%end

%group InstallUpdatePasscode

%hook SUBManager

- (void)installUpdate:(id)update passcode:(id)passcode {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        %orig;
        return;
    }
    SCIWRecordAnswer(@"update install refused (passcode)");
}

%end
%end

void SCIWInstallUpdateGuard(void) {
    Class manager = NSClassFromString(@"SUBManager");
    Class controller = NSClassFromString(@"COSSoftwareUpdateController");

    SCIWRecordClass(@"SUBManager", manager != nil);
    SCIWRecordClass(@"COSSoftwareUpdateController", controller != nil);

    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    //
    // **Each selector decides for itself, and a missing one is not a failure of the others.**
    //
    // The first version demanded two selectors and installed neither when one was absent -- so a
    // device carrying a perfectly hookable method got no hold at all and was told its signatures
    // did not match. A gate narrower than what it guards fails silently in the direction of doing
    // less, which is a rule this project already had and applied here backwards.
    //
    if (controller && SCIWEncodingMatches(controller, @"manager:scanRequestDidLocateUpdate:error:",
                                          kSCIWScanResultEncoding)) {
        %init(ScanResult);
        [installed addObject:@"-manager:scanRequestDidLocateUpdate:error:"];
    } else {
        [skipped addObject:controller
            ? SCIWDescribeSelector(controller, @"manager:scanRequestDidLocateUpdate:error:",
                                   kSCIWScanResultEncoding)
            : @"COSSoftwareUpdateController is not in this process"];
    }

    if (controller && SCIWEncodingMatches(controller, @"setUpdate:", @"v24@0:8@16")) {
        %init(SetUpdate);
        [installed addObject:@"-setUpdate:"];
    } else if (controller) {
        [skipped addObject:SCIWDescribeSelector(controller, @"setUpdate:", @"v24@0:8@16")];
    }

    if (controller && SCIWEncodingMatches(controller, @"handleManagerState:update:error:",
                                          @"v40@0:8q16@24@32")) {
        %init(ManagerState);
        [installed addObject:@"-handleManagerState:update:error:"];
    } else if (controller) {
        [skipped addObject:SCIWDescribeSelector(controller, @"handleManagerState:update:error:",
                                                @"v40@0:8q16@24@32")];
    }

    if (controller && SCIWEncodingMatches(controller, @"startSUBUpdates", @"v16@0:8")) {
        %init(PageAppears);
        [installed addObject:@"-startSUBUpdates"];
    } else if (controller) {
        [skipped addObject:SCIWDescribeSelector(controller, @"startSUBUpdates", @"v16@0:8")];
    }

    if (controller && SCIWEncodingMatches(controller, @"updateTableViewWithTask:", @"v24@0:8@?16")) {
        %init(PageRedraws);
        [installed addObject:@"-updateTableViewWithTask:"];
    } else if (controller) {
        [skipped addObject:SCIWDescribeSelector(controller, @"updateTableViewWithTask:",
                                                @"v24@0:8@?16")];
    }

    if (manager && SCIWEncodingMatches(manager, @"startDownload:", kSCIWDownloadEncoding)) {
        %init(DownloadStart);
        [installed addObject:@"-startDownload:"];
    } else if (manager) {
        [skipped addObject:SCIWDescribeSelector(manager, @"startDownload:", kSCIWDownloadEncoding)];
    }

    if (manager && SCIWEncodingMatches(manager, @"startDownload:passcode:",
                                       kSCIWDownloadPasscodeEncoding)) {
        %init(DownloadStartPasscode);
        [installed addObject:@"-startDownload:passcode:"];
    } else if (manager) {
        [skipped addObject:SCIWDescribeSelector(manager, @"startDownload:passcode:",
                                                kSCIWDownloadPasscodeEncoding)];
    }

    if (manager && SCIWEncodingMatches(manager, @"installUpdate:", kSCIWInstallEncoding)) {
        %init(InstallUpdate);
        [installed addObject:@"-installUpdate:"];
    } else if (manager) {
        [skipped addObject:SCIWDescribeSelector(manager, @"installUpdate:", kSCIWInstallEncoding)];
    }

    if (manager && SCIWEncodingMatches(manager, @"installUpdate:passcode:",
                                       kSCIWInstallPasscodeEncoding)) {
        %init(InstallUpdatePasscode);
        [installed addObject:@"-installUpdate:passcode:"];
    } else if (manager) {
        [skipped addObject:SCIWDescribeSelector(manager, @"installUpdate:passcode:",
                                                kSCIWInstallPasscodeEncoding)];
    }

    if (!manager) [skipped addObject:@"SUBManager is not in this process"];

    sciwGuardState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [NSString stringWithFormat:@"installed: %@",
                              [installed componentsJoinedByString:@", "]]
                        : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@",
                            [skipped componentsJoinedByString:@"; "]]
                      : @""];
    SCIWPublishGuardState();
}

NSString *SCIWUpdateGuardReport(void) {
    NSString *state = sciwGuardState
        ?: @"not installed — either the master switch is off or the Watch app has not run this build";

    NSMutableString *report = [NSMutableString stringWithString:state];
    if (sciwUpdateShape.length)
        [report appendFormat:@"\nthe update it saw: %@", sciwUpdateShape];
    if (sciwHeldVersion.length)
        [report appendFormat:@"\nheld: %@", sciwHeldVersion];
    if (sciwPassedVersion.length)
        [report appendFormat:@"\nlet through: %@", sciwPassedVersion];
    [report appendFormat:@"\nstamp: %lu call(s) → %lu asked → %lu row(s), %lu with a footer → "
                          @"%lu stamped%@",
     (unsigned long)sciwStampCalls, (unsigned long)sciwStampAsked, (unsigned long)sciwStampRows,
     (unsigned long)sciwStampFooters, (unsigned long)sciwPageStamps,
     sciwStampStop.length ? [@" — last stop: " stringByAppendingString:sciwStampStop] : @""];
    if (sciwPageShape.length)
        [report appendFormat:@"\nthe update page's rows (the last one carrying a footer is the "
                              @"one stamped):\n%@", sciwPageShape];
    return report;
}
