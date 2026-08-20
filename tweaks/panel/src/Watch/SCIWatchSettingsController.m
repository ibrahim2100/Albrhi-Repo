#import "SCIWatchSettingsController.h"
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import "../Localization/SCILocalize.h"
#import "../SCIPanelBadge.h"
#import "../SCIPanelHeader.h"
#import "../SCIPanelButtonAction.h"


///
/// **The switches are written to Albrhi's own preference domain, which is where the tweak reads
/// them**, and this page runs inside Settings where that domain is not the application's own. So
/// every read and write names the domain explicitly rather than going through NSUserDefaults,
/// which would silently address Settings' own preferences instead.
///
/// **The tweak's own domain, not the panel's.** The panel's domain holds `app_enabled_<bundleid>`
/// — the question "may Albrhi act in this process at all" — and it is read by every tweak here.
/// These switches belong to one tweak, so they live where that tweak looks: `com.albrhi.watch`,
/// named identically in tweaks/watch/src/Prefs.h. Two spellings of this string is a switch that
/// appears to work and changes nothing, which is a failure this project has already shipped once.
static NSString *const kSCIWatchDomain = @"com.albrhi.watch";

typedef struct { __unsafe_unretained NSString *key; BOOL defaultsTo; } SCIWatchToggle;

/// Every switch, with the default the *tweak* uses for it. Stated here rather than inferred,
/// because a page that shows a different default than the tweak applies is a screen stating the
/// opposite of what is happening -- which this project shipped once already, in NextUp.
static const SCIWatchToggle kSCIWatchToggles[] = {
    { @"watch_enabled",      NO  },
    { @"watch_pairing",      YES },
    { @"watch_capabilities", YES },
    { @"watch_apps",         YES },
    // Off: every other switch here *answers* a question iOS asks, and this one refuses to ask it.
    // Installing a pairing tweak is not a request to stop being offered watch updates.
    { @"watch_hold_updates", NO  },
};

static const size_t kSCIWatchToggleCount = sizeof(kSCIWatchToggles) / sizeof(kSCIWatchToggles[0]);

@implementation SCIWatchSettingsController

#pragma mark - Preferences

- (BOOL)sci_defaultFor:(NSString *)key {
    for (size_t i = 0; i < kSCIWatchToggleCount; i++) {
        if ([kSCIWatchToggles[i].key isEqualToString:key]) return kSCIWatchToggles[i].defaultsTo;
    }
    return NO;
}

- (BOOL)sci_readBool:(NSString *)key {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIWatchDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)kSCIWatchDomain);
    if (!value) return [self sci_defaultFor:key];

    BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : [self sci_defaultFor:key];
    CFRelease(value);
    return result;
}

- (id)watchValueForSpecifier:(PSSpecifier *)specifier {
    return @([self sci_readBool:[specifier propertyForKey:@"sciWatchKey"]]);
}

- (void)setWatchValue:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciWatchKey"];
    if (!key.length) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCIWatchDomain);
    // Written through immediately: left to cfprefsd's own schedule, a respring started seconds
    // later can read the old value, and the switch looks broken for the one action it exists to
    // be followed by.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIWatchDomain);

    if ([key isEqualToString:@"watch_enabled"]) [self viewDidLayoutSubviews];
}

#pragma mark - Rows

- (PSSpecifier *)watchGroupTitled:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:(title ?: @"")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

- (PSSpecifier *)watchSwitchTitled:(NSString *)title
                               key:(NSString *)key
                            symbol:(NSString *)symbol
                              tint:(UIColor *)tint {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:@selector(setWatchValue:specifier:)
                                                         get:@selector(watchValueForSpecifier:)
                                                      detail:Nil
                                                        cell:PSSwitchCell
                                                        edit:Nil];
    [row setProperty:key forKey:@"sciWatchKey"];
    if (symbol.length) [row setProperty:SCIPanelBadgeImage(symbol, tint) forKey:@"iconImage"];
    return row;
}

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    [specifiers addObject:[self watchGroupTitled:nil footer:SCILocalized(@"watch_master_footer")]];
    [specifiers addObject:[self watchSwitchTitled:SCILocalized(@"watch_master")
                                              key:@"watch_enabled"
                                           symbol:@"power"
                                             tint:SCIPanelAccent()]];

    [specifiers addObject:[self watchGroupTitled:SCILocalized(@"watch_answers_section")
                                          footer:SCILocalized(@"watch_answers_footer")]];
    [specifiers addObject:[self watchSwitchTitled:SCILocalized(@"watch_pairing")
                                              key:@"watch_pairing"
                                           symbol:@"link"
                                             tint:[UIColor systemBlueColor]]];
    [specifiers addObject:[self watchSwitchTitled:SCILocalized(@"watch_capabilities")
                                              key:@"watch_capabilities"
                                           symbol:@"checklist"
                                             tint:[UIColor systemTealColor]]];
    [specifiers addObject:[self watchSwitchTitled:SCILocalized(@"watch_apps")
                                              key:@"watch_apps"
                                           symbol:@"square.and.arrow.down.on.square"
                                             tint:[UIColor systemIndigoColor]]];

    [specifiers addObject:[self watchGroupTitled:SCILocalized(@"watch_updates_section")
                                          footer:SCILocalized(@"watch_updates_footer")]];
    [specifiers addObject:[self watchSwitchTitled:SCILocalized(@"watch_hold_updates")
                                              key:@"watch_hold_updates"
                                           symbol:@"hand.raised.fill"
                                             tint:[UIColor systemRedColor]]];

    //
    // **The probe's report, and a way to send it.**
    //
    // The classes this tweak wants next live in the shared cache, which iOS 16 does not expose as
    // a file. So the tweak asks them at runtime inside the processes where they exist and writes
    // what it found here. One copied report answers what extracting a three-gigabyte cache would.
    //
    [specifiers addObject:[self watchGroupTitled:SCILocalized(@"watch_report_section")
                                          footer:SCILocalized(@"watch_report_footer")]];

    PSSpecifier *report = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"watch_report_copy")
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:Nil
                                                           cell:PSButtonCell
                                                           edit:Nil];
    SCISetButtonAction(report, @selector(copyProbeReport));
    [report setProperty:SCIPanelBadgeImage(@"doc.on.doc", [UIColor systemGrayColor])
                 forKey:@"iconImage"];
    [specifiers addObject:report];

    //
    // **The restart button, on this page rather than only on the panel's root.**
    //
    // Every switch above changes what SpringBoard answers, and SpringBoard installs those answers
    // when it launches. Moving a switch here and walking away leaves the phone behaving exactly
    // as it did before, which reads as "the tweak does not work" -- so the action that makes a
    // change real sits directly under the changes.
    //
    [specifiers addObject:[self watchGroupTitled:SCILocalized(@"watch_restart_section")
                                          footer:SCILocalized(@"watch_restart_footer")]];

    PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"watch_respring")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSButtonCell
                                                             edit:Nil];
    SCISetButtonAction(respring, @selector(confirmRespring));
    [respring setProperty:@YES forKey:@"isDestructive"];
    [respring setProperty:SCIPanelBadgeImage(@"arrow.clockwise", [UIColor systemOrangeColor])
                   forKey:@"iconImage"];
    [specifiers addObject:respring];

    //
    // **A respring reloads SpringBoard and leaves the Watch app exactly as it was.** They are two
    // processes and they load this tweak separately, so the half of it that lives in the Watch app
    // needs its own button -- and the update hold lives entirely in that half.
    //
    PSSpecifier *restartApp = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"watch_restart_app")
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
    SCISetButtonAction(restartApp, @selector(restartWatchApp));
    [restartApp setProperty:SCIPanelBadgeImage(@"applewatch", SCIPanelAccent())
                     forKey:@"iconImage"];
    [specifiers addObject:restartApp];

    [specifiers addObject:[self watchGroupTitled:nil footer:SCILocalized(@"watch_credit")]];

    // Assigned to the ivar, not just returned: PSListController reads _specifiers directly in
    // places an override's return value never reaches, and a page that only returns its list
    // opens to a black screen -- which this project shipped once already.
    _specifiers = specifiers;
    return _specifiers;
}

#pragma mark - The report

/// What the tweak wrote from inside SpringBoard and the Watch app.
///
/// Read from the tweak's own domain rather than passed through some channel of its own: the probe
/// runs in two processes that Settings cannot talk to, and a preference is the one place all three
/// can meet. Empty means the probe has not run since the tweak was switched on — which is itself
/// the answer, and the message says so rather than showing a blank sheet.
- (NSString *)stringForKey:(NSString *)key {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)kSCIWatchDomain);
    if (!value) return nil;

    if (CFGetTypeID(value) != CFStringGetTypeID()) { CFRelease(value); return nil; }
    return (__bridge_transfer NSString *)value;
}

- (NSString *)probeReport {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIWatchDomain);

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    // What the Watch app announced about itself, recorded by SpringBoard because the Watch app
    // may not be able to write here at all. It goes first: it decides how the empty section
    // below should be read, and a reader who meets the emptiness first has already guessed.
    NSString *bridge = [self stringForKey:@"watch_bridge_state"];
    if (bridge.length) [parts addObject:[@"watch app: " stringByAppendingString:bridge]];

    // **One section per process.** Both wrote the same key once, so whichever launched last was
    // the only one ever read -- and the section that mattered was always the missing one.
    for (NSString *process in @[@"com.apple.springboard", @"com.apple.Bridge"]) {
        NSString *report = [self stringForKey:
            [@"watch_probe_report_" stringByAppendingString:process]];
        // No header added here: the probe writes its own `in <process>` line, and adding a second
        // printed it twice. Two lists describing one thing again — the same shape as the report
        // that had rows the screen did not.
        [parts addObject:report.length
            ? report
            : [NSString stringWithFormat:@"in %@\nNOT REACHED — the tweak never ran here. "
                                          @"On a jailbreak with per-app injection, enable it for "
                                          @"this process.", process]];
    }

    // The update hold's own verdict, which is the line a fix gets written from: either it
    // installed, or it names both encodings that disagreed.
    NSString *guard = [self stringForKey:@"watch_update_guard"];
    [parts addObject:guard.length
        ? [@"update hold: " stringByAppendingString:guard]
        : @"update hold: no verdict — the Watch app has not run this build"];

    return [parts componentsJoinedByString:@"\n\n"];
}

- (void)copyProbeReport {
    NSString *report = [self probeReport];

    if (!report.length) {
        UIAlertController *note =
            [UIAlertController alertControllerWithTitle:SCILocalized(@"watch_report_copy")
                                                message:SCILocalized(@"watch_report_empty")
                                         preferredStyle:UIAlertControllerStyleAlert];
        [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];
        [self presentViewController:note animated:YES completion:nil];
        return;
    }

    [UIPasteboard generalPasteboard].string = report;

    UIAlertController *done =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"watch_report_copied")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:done animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [done dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - Restarting

- (void)confirmRespring {
    UIAlertController *ask =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"watch_respring")
                                            message:SCILocalized(@"watch_respring_confirm")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"watch_respring")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
        [self respring];
    }]];

    [self presentViewController:ask animated:YES completion:nil];
}

///
/// The same private pair the panel's root page uses, asked for rather than assumed.
///
/// `SBSRelaunchAction` and `FBSSystemService` are private, so every step is guarded and a missing
/// piece produces a message rather than a crash inside Settings. Option 4 is the fade-to-black
/// transition, which is what a respring looks like everywhere else on the system.
///
- (void)respring {
    Class actionClass = NSClassFromString(@"SBSRelaunchAction");
    Class serviceClass = NSClassFromString(@"FBSSystemService");

    SEL make = NSSelectorFromString(@"actionWithReason:options:targetURL:");
    SEL shared = NSSelectorFromString(@"sharedService");
    SEL send = NSSelectorFromString(@"sendActions:withResult:");

    if (!actionClass || !serviceClass ||
        ![actionClass respondsToSelector:make] || ![serviceClass respondsToSelector:shared]) {
        [self sayRestartFailed];
        return;
    }

    @try {
        id action = ((id (*)(id, SEL, id, NSUInteger, id))objc_msgSend)(
            actionClass, make, @"Albrhi Watch", (NSUInteger)4, nil);
        id service = ((id (*)(id, SEL))objc_msgSend)(serviceClass, shared);

        if (!action || !service || ![service respondsToSelector:send]) {
            [self sayRestartFailed];
            return;
        }

        ((void (*)(id, SEL, id, id))objc_msgSend)(service, send, [NSSet setWithObject:action], nil);
    } @catch (__unused NSException *exception) {
        [self sayRestartFailed];
    }
}

///
/// Ends the Watch app so its next launch carries this tweak.
///
/// `-terminateApplication:forReason:andReport:withDescription:` is FrontBoard's own way of ending
/// an application, and it is what a restart of one app honestly is: iOS starts it again the next
/// time it is opened. Guarded like everything private here, and it names the app rather than
/// killing by pid -- a pid found by searching is a pid that can belong to something else by the
/// time it is used.
///
- (void)restartWatchApp {
    Class serviceClass = NSClassFromString(@"FBSSystemService");
    SEL shared = NSSelectorFromString(@"sharedService");
    SEL terminate = NSSelectorFromString(@"terminateApplication:forReason:andReport:withDescription:");

    id service = (serviceClass && [serviceClass respondsToSelector:shared])
        ? ((id (*)(id, SEL))objc_msgSend)(serviceClass, shared) : nil;

    if (![service respondsToSelector:terminate]) {
        [self sayRestartFailed];
        return;
    }

    ((void (*)(id, SEL, id, NSInteger, BOOL, id))objc_msgSend)(
        service, terminate, @"com.apple.Bridge", 1, NO, @"Albrhi Watch");
}

- (void)sayRestartFailed {
    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"watch_respring")
                                            message:SCILocalized(@"watch_respring_failed")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

#pragma mark - Header

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UITableView *table = self.table;
    CGFloat width = table.bounds.size.width;
    if (width <= 0) return;

    BOOL on = [self sci_readBool:@"watch_enabled"];
    if (table.tableHeaderView
        && ABS(table.tableHeaderView.frame.size.width - width) < 0.5
        && table.tableHeaderView.tag == (on ? 1 : 2)) {
        return;
    }

    UIView *header = [SCIPanelHeader pageHeaderForWidth:width
                                                 symbol:@"applewatch"
                                                   tint:SCIPanelAccent()
                                                  title:SCILocalized(@"watch_title")
                                               subtitle:SCILocalized(@"watch_page_subtitle")
                                                  state:SCILocalized(on ? @"watch_state_on"
                                                                        : @"watch_state_off")
                                                     on:on];
    header.tag = on ? 1 : 2;
    table.tableHeaderView = header;
}

@end
