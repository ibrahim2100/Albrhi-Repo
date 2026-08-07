#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "SCIPanelHeader.h"
#import "Localization/SCILocalize.h"

NSString *SCIVersionString = @"v0.6.0";  // AlbrhiPanel

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

        // The app's own icon, so the list is scanned by eye rather than read.
        //
        // Two rows of text that differ by one word are two rows a person has to read;
        // the Instagram glyph and the YouTube glyph are told apart before reading starts.
        // Nil is fine and means no picture, never a blank space where one was promised.
        if (entry.appIcon) [row setProperty:entry.appIcon forKey:@"iconImage"];

        // An app that is not on the phone gets a switch that cannot be moved. Offering a
        // live switch for an app you do not have is offering a control over nothing.
        if (!entry.appInstalled) {
            [row setProperty:@NO forKey:@"enabled"];
        }

        [specifiers addObject:row];
    }

    [specifiers addObjectsFromArray:[self versionSpecifiersFor:entries]];

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

    // The name at the end, in the last footer, where a signature belongs.
    //
    // A value row already says who made it; this is the other thing — the licence and the
    // credit SCInsta is owed, which is a condition of using it and not a courtesy. Both
    // are in the package metadata too, and both being visible on the device matters more
    // than either being tidy.
    PSSpecifier *signature = [PSSpecifier preferenceSpecifierNamed:@""
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
    [signature setProperty:SCILocalized(@"about_signature") forKey:@"footerText"];
    [specifiers addObject:signature];

    _specifiers = specifiers;
    return _specifiers;
}

/// What each tweak was built against, beside what is on the phone.
///
/// The section exists because "it stopped working after an update" is the single most
/// common thing anyone reports, and this is the page that can answer it without a report
/// being written at all. A row reads "410.1.0 · tested" when they agree and
/// "412.0.0 · tested on 410.1.0" when they do not.
///
/// Nothing is disabled on a mismatch. Nothing is pinned to a version number anywhere in
/// this project and a newer app usually works fine; the point is to show the one fact
/// that explains it when it does not.
- (NSArray<PSSpecifier *> *)versionSpecifiersFor:(NSArray<SCIPanelEntry *> *)entries {
    NSMutableArray<SCIPanelEntry *> *known = [NSMutableArray array];
    for (SCIPanelEntry *entry in entries) {
        if (entry.testedVersion.length || entry.appVersion.length) [known addObject:entry];
    }
    if (!known.count) return @[];

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_versions")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    [group setProperty:SCILocalized(@"versions_footer") forKey:@"footerText"];

    NSMutableArray<PSSpecifier *> *rows = [NSMutableArray arrayWithObject:group];

    for (SCIPanelEntry *entry in known) {
        NSString *value;

        if (!entry.appVersion.length) {
            // Not installed, so there is nothing to compare. The tested version is still
            // worth stating: it is what this tweak is for.
            value = [NSString stringWithFormat:SCILocalized(@"versions_tested_only"),
                     entry.testedVersion ?: @"—"];
        } else if (!entry.testedVersion.length) {
            value = entry.appVersion;
        } else if ([entry runsTestedVersion]) {
            value = [NSString stringWithFormat:SCILocalized(@"versions_match"), entry.appVersion];
        } else {
            value = [NSString stringWithFormat:SCILocalized(@"versions_differ"),
                     entry.appVersion, entry.testedVersion];
        }

        [rows addObject:[self valueRow:entry.appName value:value]];
    }

    return rows;
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

/// The header is fitted here rather than in -viewDidLoad.
///
/// A table header has to be given a frame, and the width to fit it to is the table's —
/// which is not final until the view has been laid out. Fitting it in -viewDidLoad gives
/// it the width of a view that has not been sized yet, and the header comes out either
/// clipped or floating in the middle of the page.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UITableView *table = self.table;
    CGFloat width = table.bounds.size.width;
    if (width <= 0) return;

    // Rebuilt only when the width actually changed -- on rotation, on an iPad split.
    // -viewDidLayoutSubviews runs constantly, and building a view on each pass would
    // rebuild the header while the user is scrolling past it.
    if (table.tableHeaderView && ABS(table.tableHeaderView.frame.size.width - width) < 0.5) return;

    UIView *header = [SCIPanelHeader viewForWidth:width version:SCIVersionString];
    if (header) table.tableHeaderView = header;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
