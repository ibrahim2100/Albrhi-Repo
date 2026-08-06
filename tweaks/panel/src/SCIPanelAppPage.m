#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "Localization/SCILocalize.h"

///
/// One app: what is loaded into it, and the switch that stands our tweaks down.
///
/// **What the switch really does, said plainly, because the difference matters.** It does
/// not change what gets injected. Rewriting a tweak's filter file needs root and this runs
/// as `mobile`, so nothing here can stop a dylib being loaded. What it changes is what the
/// loaded code *does*: every Albrhi tweak reads its settings through one function, that
/// function asks this switch first, and with it off every feature answers %orig and the app
/// behaves as though the tweak were not there.
///
/// It therefore governs Albrhi's own tweaks and nothing else. A switch that appeared to turn
/// DLEasy off and silently did nothing would be worse than no switch, so other people's
/// tweaks are listed and not offered one.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///
@interface SCIPanelAppController : PSListController
@property (nonatomic, strong) SCIPanelApp *app;
@end

@implementation SCIPanelAppController

/// The panel's own preference domain, named identically in shared/src/SCIPanelGate.m.
/// Two spellings of this string is a switch that appears to work and changes nothing.
static NSString *const kSCIPanelDomain = @"com.albrhi.panel";

/// Whether any tweak in this app is one of ours, and so answers the switch.
- (BOOL)hasAlbrhiTweak {
    for (SCIPanelTweak *tweak in self.app.tweaks) {
        if ([tweak.name hasPrefix:@"Albrhi"]) return YES;
    }
    return NO;
}

- (NSArray *)specifiers {
    // Rebuilt from the bundle identifier the row carried, because the model object cannot
    // travel through a specifier and a stale copy would describe a device that has changed.
    NSString *identifier = [self.specifier propertyForKey:@"sciBundleIdentifier"];
    for (SCIPanelApp *candidate in [SCIPanelScan allApps]) {
        if ([candidate.bundleIdentifier isEqualToString:identifier]) {
            self.app = candidate;
            break;
        }
    }

    NSMutableArray *specifiers = [NSMutableArray array];

    if ([self hasAlbrhiTweak]) {
        PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"app_switch_section")
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
        [group setProperty:SCILocalized(@"app_switch_footer") forKey:@"footerText"];
        [specifiers addObject:group];

        PSSpecifier *toggle =
            [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"app_switch")
                                           target:self
                                              set:@selector(setEnabled:forSpecifier:)
                                              get:@selector(isEnabledForSpecifier:)
                                           detail:Nil
                                             cell:PSSwitchCell
                                             edit:Nil];
        [specifiers addObject:toggle];
    }

    PSSpecifier *listGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"app_tweaks_section")
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
    if (![self hasAlbrhiTweak] && self.app.tweaks.count) {
        [listGroup setProperty:SCILocalized(@"app_others_footer") forKey:@"footerText"];
    }
    [specifiers addObject:listGroup];

    for (SCIPanelTweak *tweak in self.app.tweaks) {
        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:tweak.name
                                                          target:self
                                                             set:NULL
                                                             get:NULL
                                                          detail:Nil
                                                            cell:PSTitleValueCell
                                                            edit:Nil];
        // Megabytes to one decimal: a tweak's size is the only number here that tells you
        // anything, and bytes tell you nothing at a glance.
        [row setProperty:[NSString stringWithFormat:@"%.1f MB", tweak.size / 1048576.0]
                  forKey:@"value"];
        [specifiers addObject:row];
    }

    _specifiers = specifiers;
    return _specifiers;
}

- (id)isEnabledForSpecifier:(__unused PSSpecifier *)specifier {
    NSString *key = [@"app_enabled_" stringByAppendingString:self.app.bundleIdentifier];

    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kSCIPanelDomain);

    // Never written means on. A device that has not used this panel has every tweak it
    // installed deliberately still working, which is the only safe reading of an absence.
    if (!value) return @YES;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : YES;
    CFRelease(value);
    return @(on);
}

- (void)setEnabled:(NSNumber *)value forSpecifier:(__unused PSSpecifier *)specifier {
    NSString *key = [@"app_enabled_" stringByAppendingString:self.app.bundleIdentifier];

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCIPanelDomain);

    // Written through immediately. Left to its own schedule, cfprefsd can hold this for
    // long enough that relaunching the app -- which is exactly what someone does next --
    // reads the old value and the switch looks broken.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelDomain);

    // Said once, because the effect is not immediate and silence would read as a fault.
    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:self.app.name
                                            message:SCILocalized(@"app_switch_restart")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.app.name ?: SCILocalized(@"section_apps");
}

@end
