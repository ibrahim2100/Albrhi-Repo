#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "SCIPanelHelper.h"
#import "Localization/SCILocalize.h"

///
/// One tweak, and every app it could load into.
///
/// This is the screen the panel was asked for: pick a dylib, see the apps, switch it on or
/// off per app. Unlike the per-app switch, this changes the filter file itself — so the
/// tweak genuinely is not loaded into an app it is switched off for, rather than loaded and
/// standing down.
///
/// **Only apps the tweak can plausibly serve are listed.** A filter naming twenty social
/// apps has nothing to say about a banking app, and offering a switch for every app on the
/// device would bury the twenty that matter under sixty that do not. The list is therefore
/// the union of what the filter already names and what it has been switched off from — an
/// app removed from the filter has to stay visible, or turning it off would make the switch
/// that turns it back on disappear.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///
@interface SCIPanelTweakController : PSListController
@property (nonatomic, strong) SCIPanelTweak *tweak;
@property (nonatomic, strong) NSArray<SCIPanelApp *> *candidates;
@end

@implementation SCIPanelTweakController

/// Apps switched off from this tweak, remembered so they can be switched back on.
///
/// Kept in the panel's own preferences and not inferred, because "not in the filter" and
/// "removed from the filter by me" are indistinguishable from the file — and an app that
/// vanishes from the list the moment it is turned off is a one-way door.
static NSString *const kSCIPanelDomain = @"com.albrhi.panel";

- (NSString *)removedKey {
    return [@"removed_from_" stringByAppendingString:self.tweak.name];
}

- (NSArray<NSString *> *)removedIdentifiers {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[self removedKey], (__bridge CFStringRef)kSCIPanelDomain);
    if (!value) return @[];

    NSArray *list = CFGetTypeID(value) == CFArrayGetTypeID()
        ? (__bridge NSArray *)value : @[];
    NSArray *copy = [list copy];
    CFRelease(value);
    return copy;
}

- (void)setRemovedIdentifiers:(NSArray<NSString *> *)identifiers {
    CFPreferencesSetAppValue((__bridge CFStringRef)[self removedKey],
                             (__bridge CFPropertyListRef)identifiers,
                             (__bridge CFStringRef)kSCIPanelDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelDomain);
}

- (NSArray *)specifiers {
    NSString *wanted = [self.specifier propertyForKey:@"sciTweakName"];
    for (SCIPanelTweak *candidate in [SCIPanelScan installedTweaks]) {
        if ([candidate.name isEqualToString:wanted]) { self.tweak = candidate; break; }
    }

    NSArray<NSString *> *removed = [self removedIdentifiers];
    NSMutableArray<SCIPanelApp *> *candidates = [NSMutableArray array];
    for (SCIPanelApp *app in [SCIPanelScan allApps]) {
        BOOL inFilter = [self.tweak.bundles containsObject:app.bundleIdentifier.lowercaseString];
        BOOL wasRemoved = [removed containsObject:app.bundleIdentifier];
        if (inFilter || wasRemoved) [candidates addObject:app];
    }
    self.candidates = candidates;

    NSMutableArray *specifiers = [NSMutableArray array];

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"tweak_apps_section")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    // Written out rather than as a ternary inside the call: tools/check.py finds used
    // strings by looking for SCILocalized(@"..."), so a key reached through an expression
    // reads as an orphan and every real orphan hides among the false ones.
    NSString *footer = SCILocalized(@"tweak_apps_footer");
    if (!SCIPanelHelperReady()) footer = SCILocalized(@"helper_missing");
    [group setProperty:footer forKey:@"footerText"];
    [specifiers addObject:group];

    if (!candidates.count) {
        PSSpecifier *note = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"tweak_no_apps")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSTitleValueCell
                                                             edit:Nil];
        [specifiers addObject:note];
    }

    for (SCIPanelApp *app in candidates) {
        PSSpecifier *row =
            [PSSpecifier preferenceSpecifierNamed:app.name
                                           target:self
                                              set:@selector(setOn:forSpecifier:)
                                              get:@selector(isOnForSpecifier:)
                                           detail:Nil
                                             cell:PSSwitchCell
                                             edit:Nil];
        [row setProperty:app.bundleIdentifier forKey:@"sciBundleIdentifier"];

        // A switch nothing can act on is greyed rather than offered: flipping it and
        // watching it spring back says nothing about why.
        if (!SCIPanelHelperReady()) [row setProperty:@NO forKey:@"enabled"];

        [specifiers addObject:row];
    }

    _specifiers = specifiers;
    return _specifiers;
}

- (id)isOnForSpecifier:(PSSpecifier *)specifier {
    NSString *identifier = [specifier propertyForKey:@"sciBundleIdentifier"];

    // Read from the filter itself rather than from a preference. The file is the truth --
    // a package update rewrites it, and a remembered answer would then be confidently wrong.
    return @([self.tweak.bundles containsObject:identifier.lowercaseString]);
}

- (void)setOn:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
    NSString *identifier = [specifier propertyForKey:@"sciBundleIdentifier"];
    BOOL wanted = value.boolValue;

    NSError *error = nil;
    NSString *filterName = self.tweak.filterPath.lastPathComponent;

    if (!SCIPanelSetTweak(filterName, identifier, wanted, &error)) {
        [self say:SCILocalized(@"change_failed")
          message:error.localizedDescription ?: SCILocalized(@"change_failed")];
        [self reloadSpecifiers];
        return;
    }

    // Remembered so the app stays on this list after being switched off, and forgotten
    // again when it is switched back on.
    NSMutableArray *removed = [[self removedIdentifiers] mutableCopy];
    if (wanted) {
        [removed removeObject:identifier];
    } else if (![removed containsObject:identifier]) {
        [removed addObject:identifier];
    }
    [self setRemovedIdentifiers:removed];

    [self say:self.tweak.name message:SCILocalized(@"change_respring")];
    [self reloadSpecifiers];
}

- (void)say:(NSString *)title message:(NSString *)message {
    UIAlertController *note = [UIAlertController alertControllerWithTitle:title
                                                                 message:message
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.tweak.name ?: SCILocalized(@"section_tweaks");
}

@end
