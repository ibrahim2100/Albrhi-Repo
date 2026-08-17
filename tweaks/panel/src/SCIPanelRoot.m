#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "SCIPanelHeader.h"
#import "SCIPanelAppCell.h"
#import "SCIPanelDomain.h"
#import "SCIPanelButtonAction.h"
#import "Localization/SCILocalize.h"
#import <objc/message.h>
#import <objc/runtime.h>

NSString *SCIVersionString = @"v0.8.1";  // AlbrhiPanel

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
static NSString *const kSCIPanelDomain = kSCIPanelPreferenceDomain;

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
        PSSpecifier *row;

        if (entry.detailControllerClassName.length) {
            // A tweak that declared its own settings page (SCIPanelDetailController)
            // gets a link row that pushes to it, not a switch on this list -- Albrhi
            // CarPlay's master on/off lives inside that page instead, alongside the
            // settings a single switch cell has no room for.
            Class detailClass = NSClassFromString(entry.detailControllerClassName);
            row = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                 target:self
                                                    set:NULL
                                                    get:NULL
                                                 detail:detailClass
                                                   cell:PSLinkCell
                                                   edit:Nil];
        } else {
            row = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                 target:self
                                                    set:@selector(setOn:forSpecifier:)
                                                    get:@selector(isOnForSpecifier:)
                                                 detail:Nil
                                                   cell:PSSwitchCell
                                                   edit:Nil];

            // An app that is not on the phone gets a switch that cannot be moved.
            // Offering a live switch for an app you do not have is offering a control
            // over nothing. A row that pushes to its own page has nothing to dim --
            // tapping it always works, whichever of its two processes is running.
            if (!entry.appInstalled) {
                [row setProperty:@NO forKey:@"enabled"];
            }
        }

        [row setProperty:entry.bundleIdentifier forKey:@"sciBundleIdentifier"];

        // Everything the versions section used to say, on the row it is about.
        //
        // The cell class is only set on switch rows: a row that pushes to its own page is a
        // PSLinkCell and giving it a switch cell's class would replace the disclosure
        // chevron with a switch that controls nothing.
        BOOL warn = NO;
        NSString *subtitle = [self subtitleForEntry:entry warning:&warn];
        if (subtitle.length && !entry.detailControllerClassName.length) {
            [row setProperty:subtitle forKey:@"sciSubtitle"];
            [row setProperty:@(warn) forKey:@"sciSubtitleIsWarning"];
            // A Class, not its name.
            //
            // This was set to the string @"SCIPanelAppCell", and Preferences takes this
            // property as a Class and sends class messages to it -- so it messaged an
            // NSString and Settings died the moment the page was opened. The name reads
            // identically in the source and is a completely different object.
            [row setProperty:[SCIPanelAppCell class] forKey:@"cellClass"];
        }

        // The app's own icon, so the list is scanned by eye rather than read.
        //
        // Two rows of text that differ by one word are two rows a person has to read;
        // the Instagram glyph and the YouTube glyph are told apart before reading starts.
        // Nil is fine and means no picture, never a blank space where one was promised.
        if (entry.appIcon) [row setProperty:entry.appIcon forKey:@"iconImage"];

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

    [specifiers addObject:[self valueRow:SCILocalized(@"about_version")
                                   value:[self displayedVersion]]];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_author")
                                   value:SCILocalized(@"about_author_name")]];

    // Respring, in its own group so a destructive-looking button is never a mis-tap away
    // from a row that does nothing.
    PSSpecifier *restartGroup = [PSSpecifier preferenceSpecifierNamed:@""
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:Nil
                                                                 cell:PSGroupCell
                                                                 edit:Nil];
    [restartGroup setProperty:SCILocalized(@"respring_note") forKey:@"footerText"];
    [specifiers addObject:restartGroup];

    PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"respring")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSButtonCell
                                                             edit:Nil];
    SCISetButtonAction(respring, @selector(confirmRespring));
    [respring setProperty:@YES forKey:@"isDestructive"];
    [specifiers addObject:respring];

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
///
/// What a row says under the app's name.
///
/// This was a whole second section that listed every app again to state two version
/// numbers. Two passes down the same list to answer one question about one app -- and the
/// switch was in the first pass while the reason you might want to move it was in the
/// second. It is one line under the name now, and the section is gone.
///
/// Every string it can produce is the one the old section used; nothing here changes what
/// is said, only where. Returns nil when there is genuinely nothing to say, and the cell
/// hides the line rather than reserving an empty one.
- (NSString *)subtitleForEntry:(SCIPanelEntry *)entry warning:(BOOL *)warning {
    if (warning) *warning = NO;

    // A row with its own settings page speaks for itself there, and never declares a tested
    // app version -- it does not target one real app the way the others do.
    if (entry.detailControllerClassName.length) return nil;

    if (!entry.appInstalled) return SCILocalized(@"versions_not_installed");

    if (!entry.appVersion.length && !entry.testedVersion.length) {
        return SCILocalized(@"versions_unknown");
    }
    if (!entry.appVersion.length) {
        // Nothing to compare against. The tested version is still worth stating: it is what
        // this tweak is for.
        return [NSString stringWithFormat:SCILocalized(@"versions_tested_only"),
                entry.testedVersion];
    }
    if (!entry.testedVersion.length) return entry.appVersion;

    if ([entry runsTestedVersion]) {
        return [NSString stringWithFormat:SCILocalized(@"versions_match"), entry.appVersion];
    }

    // The one case worth colouring: this build has not been verified against the app on the
    // phone. A caution, not a fault -- see the cell for why it is amber and not red.
    if (warning) *warning = YES;
    return [NSString stringWithFormat:SCILocalized(@"versions_differ"),
            entry.appVersion, entry.testedVersion];
}

/// A row showing a fixed value on the right.
///
/// **The getter is not optional, and that is what was wrong.** Setting the `value`
/// property and passing `get:NULL` reads like it should work and produces a row with the
/// title and an empty space — "Made by" with nobody's name after it. A PSTitleValueCell
/// asks its specifier for a value through the get selector; with none there is nothing
/// to ask and nothing is what it draws. Every value row on this page was blank for it.
- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:@selector(fixedValue:)
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:(value ?: @"") forKey:@"value"];
    return row;
}

- (id)fixedValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"value"] ?: @"";
}

/// The number to put in front of someone.
///
/// What dpkg says is installed, which is the combined package they chose. This bundle's
/// own `SCIVersionString` only when nothing can be read — and then it is shown with the
/// component's name attached, because "0.6.0" on its own is a number that matches nothing
/// they have ever seen.
- (NSString *)displayedVersion {
    NSString *installed = [SCIPanelScan installedSuiteVersion];
    if (installed.length) return installed;

    return [NSString stringWithFormat:SCILocalized(@"about_version_panel"), SCIVersionString];
}

// MARK: - Respring

- (void)confirmRespring {
    UIAlertController *ask =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"respring")
                                            message:SCILocalized(@"respring_confirm")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"respring")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
        [self respring];
    }]];

    [self presentViewController:ask animated:YES completion:nil];
}

/// Asks the system to restart SpringBoard.
///
/// **Not `killall SpringBoard`.** This bundle runs as `mobile` inside Settings and has no
/// business signalling another process even if it were permitted — the supported route is
/// to ask FrontBoard for a relaunch, which is the same one the Settings app itself uses
/// when a language changes.
///
/// Every class and selector here is looked up at runtime and checked. A respring button
/// that does nothing is a disappointment; a preference bundle that throws while Settings
/// is showing it is a Settings app that closes.
- (void)respring {
    Class actionClass = NSClassFromString(@"SBSRelaunchAction");
    Class serviceClass = NSClassFromString(@"FBSSystemService");

    SEL make = NSSelectorFromString(@"actionWithReason:options:targetURL:");
    SEL shared = NSSelectorFromString(@"sharedService");
    SEL send = NSSelectorFromString(@"sendActions:withResult:");

    if (!actionClass || !serviceClass ||
        ![actionClass respondsToSelector:make] || ![serviceClass respondsToSelector:shared]) {
        [self sayRespringFailed];
        return;
    }

    @try {
        // Option 4 is RelaunchActionOptionsFadeToBlackTransition, which is what a respring
        // looks like everywhere else on the system.
        id action = ((id (*)(id, SEL, id, NSUInteger, id))objc_msgSend)(
            actionClass, make, @"Albrhi", (NSUInteger)4, nil);

        id service = ((id (*)(id, SEL))objc_msgSend)(serviceClass, shared);
        if (!action || !service || ![service respondsToSelector:send]) {
            [self sayRespringFailed];
            return;
        }

        ((void (*)(id, SEL, id, id))objc_msgSend)(
            service, send, [NSSet setWithObject:action], nil);
    } @catch (__unused NSException *exception) {
        [self sayRespringFailed];
    }
}

- (void)sayRespringFailed {
    UIAlertController *note =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"respring")
                                            message:SCILocalized(@"respring_failed")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

/// The same question -isOnForSpecifier: answers, asked about an identifier instead of a row.
///
/// The header needs the count before any specifier exists to ask. Sharing this one reader is
/// what stops the pill and the switches from drifting apart -- the panel already answers this
/// question in three places across two processes, and CLAUDE.md records what the third one
/// cost when it was missed.
- (NSNumber *)isOnForSpecifierWithIdentifier:(NSString *)identifier {
    if (!identifier.length) return @NO;

    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[@"app_enabled_" stringByAppendingString:identifier],
        (__bridge CFStringRef)kSCIPanelDomain);

    if (!value) return @NO;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : NO;
    CFRelease(value);
    return @(on);
}

- (NSString *)keyFor:(PSSpecifier *)specifier {
    return [@"app_enabled_" stringByAppendingString:
        [specifier propertyForKey:@"sciBundleIdentifier"]];
}

- (id)isOnForSpecifier:(PSSpecifier *)specifier {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[self keyFor:specifier], (__bridge CFStringRef)kSCIPanelDomain);

    // Never written means off, and this **must** match SCIPanelGate's reading exactly.
    //
    // These are two separate answers to one question -- the panel decides what the switch
    // looks like, the gate decides whether the dylib does anything -- and they are read in
    // different processes from different code. Leaving this one at YES while the gate moved
    // to NO would draw every switch on while every tweak stayed off: the worst of the two
    // possible bugs, because the screen would be actively lying rather than merely
    // surprising. The reasoning for opt-in is written out once, in SCIPanelGate.h.
    if (!value) return @NO;

    BOOL on = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : NO;
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

    // Counted here rather than cached, so the pill can never disagree with the switches
    // below it -- -viewWillAppear reloads the specifiers on every return to this page, and
    // a header holding its own tally would keep yesterday's answer.
    NSArray<SCIPanelEntry *> *entries = [SCIPanelScan entries];
    NSInteger on = 0;
    for (SCIPanelEntry *entry in entries) {
        if (!entry.appInstalled) continue;
        if ([[self isOnForSpecifierWithIdentifier:entry.bundleIdentifier] boolValue]) on++;
    }

    UIView *header = [SCIPanelHeader viewForWidth:width
                                          version:[self displayedVersion]
                                               on:on
                                               of:(NSInteger)entries.count];
    if (header) table.tableHeaderView = header;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
