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

    [specifiers addObject:[self watchGroupTitled:nil footer:SCILocalized(@"watch_credit")]];

    // Assigned to the ivar, not just returned: PSListController reads _specifiers directly in
    // places an override's return value never reaches, and a page that only returns its list
    // opens to a black screen -- which this project shipped once already.
    _specifiers = specifiers;
    return _specifiers;
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
