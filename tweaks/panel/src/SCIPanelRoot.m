#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "Localization/SCILocalize.h"

NSString *SCIVersionString = @"v0.5.0";  // AlbrhiPanel

///
/// Albrhi's own control panel, in the iOS Settings app.
///
/// One switch per app Albrhi patches, and nothing else on the screen. This is the shape
/// DLEasy has and it is the right one: a tweak's settings belong somewhere you can reach
/// without opening the app it changes.
///
/// **The switch does not stop the dylib loading; it stops it doing anything.** Changing what
/// gets injected means editing a root-owned filter file, and a preference bundle runs as
/// `mobile`. Every Albrhi tweak instead reads its settings through one function, that
/// function asks this switch first, and with it off every feature answers %orig — the app
/// behaves exactly as though the tweak were not installed.
///
/// Standing down that way rather than skipping hook installation is deliberate. Hooks are
/// installed from a dozen constructors whose order is undefined, so a gate on installation
/// would sometimes catch half of them and leave the app patched in part. Installed-but-inert
/// has no such state.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///
@interface SCIPanelRootController : PSListController
@end

@implementation SCIPanelRootController

/// Named identically in shared/src/SCIPanelGate.m, which is the half that reads it. Two
/// spellings of this string is a switch that appears to work and changes nothing.
static NSString *const kSCIPanelDomain = @"com.albrhi.panel";

/// Rebuilt on every appearance rather than cached for the life of the process.
///
/// Settings keeps a preference bundle loaded after its page is closed, so a cached list
/// would still show a tweak that has since been uninstalled.
- (NSArray *)specifiers {
    NSArray<SCIPanelEntry *> *entries = [SCIPanelScan entries];
    NSMutableArray *specifiers = [NSMutableArray array];

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_apps")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    [group setProperty:SCILocalized(@"apps_footer") forKey:@"footerText"];
    [specifiers addObject:group];

    if (!entries.count) {
        PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"apps_none")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSTitleValueCell
                                                             edit:Nil];
        [specifiers addObject:none];
    }

    for (SCIPanelEntry *entry in entries) {
        PSSpecifier *row =
            [PSSpecifier preferenceSpecifierNamed:entry.appName
                                           target:self
                                              set:@selector(setOn:forSpecifier:)
                                              get:@selector(isOnForSpecifier:)
                                           detail:Nil
                                             cell:PSSwitchCell
                                             edit:Nil];
        [row setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];

        // An app that is not on the phone gets a switch that cannot be moved, and a
        // subtitle saying why. Offering a live switch for an app you do not have is
        // offering a control over nothing.
        if (!entry.appInstalled) {
            [row setProperty:@NO forKey:@"enabled"];
        }

        [specifiers addObject:row];
    }

    PSSpecifier *about = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_about")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    [about setProperty:SCILocalized(@"about_note") forKey:@"footerText"];
    [specifiers addObject:about];

    [specifiers addObject:[self valueRow:SCILocalized(@"about_version") value:SCIVersionString]];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_author")
                                   value:SCILocalized(@"about_author_name")]];

    _specifiers = specifiers;
    return _specifiers;
}

- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:NULL
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:value forKey:@"value"];
    return row;
}

- (NSString *)keyFor:(PSSpecifier *)specifier {
    return [@"app_enabled_" stringByAppendingString:
        [specifier propertyForKey:@"sciBundleIdentifier"]];
}

- (id)isOnForSpecifier:(PSSpecifier *)specifier {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[self keyFor:specifier], (__bridge CFStringRef)kSCIPanelDomain);

    // Never written means on. A device that has not opened this panel has every tweak it
    // installed deliberately still working, which is the only safe reading of an absence.
    if (!value) return @YES;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : YES;
    CFRelease(value);
    return @(on);
}

- (void)setOn:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
    CFPreferencesSetAppValue((__bridge CFStringRef)[self keyFor:specifier],
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCIPanelDomain);

    // Written through immediately. Left to its own schedule, cfprefsd can hold this long
    // enough that relaunching the app -- exactly what someone does next -- reads the old
    // value and the switch looks broken.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelDomain);

    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:specifier.name
                                            message:SCILocalized(@"switch_restart")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"panel_title");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
