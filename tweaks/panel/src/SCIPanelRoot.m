#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "SCIPanelScan.h"
#import "Localization/SCILocalize.h"

NSString *SCIVersionString = @"v0.2.0";  // AlbrhiPanel

///
/// The screen Settings opens.
///
/// A PSListController, and its specifiers are built in code rather than loaded from a
/// plist. The whole point of this panel is that its contents depend on what is on the
/// device — a static plist could describe a fixed set of rows and this has none.
///
/// **This screen still only reads.** The one thing the panel writes is the per-app switch,
/// and that lives on the detail page in SCIPanelAppPage.m — nothing is moved, and no
/// filter file is edited anywhere. Changing what gets *injected* needs root; changing what
/// the injected code *does* does not, and that is the line this version stays on.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///
@interface SCIPanelRootController : PSListController
@end

@implementation SCIPanelRootController

/// Built once per appearance rather than cached for the life of the process.
///
/// Settings keeps a preference bundle loaded after its page is closed, so a cached list
/// would still show a tweak that has since been uninstalled -- and being wrong about what
/// is on the device is the one thing this panel cannot afford.
- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    NSArray<SCIPanelTweak *> *tweaks = [SCIPanelScan installedTweaks];
    NSArray<SCIPanelApp *> *apps = [SCIPanelScan affectedApps];

    // ---- what the device looks like, in two numbers
    PSSpecifier *summary = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_summary")
                                                          target:self
                                                             set:NULL
                                                             get:NULL
                                                          detail:Nil
                                                            cell:PSGroupCell
                                                            edit:Nil];
    [specifiers addObject:summary];
    [specifiers addObject:[self valueRow:SCILocalized(@"summary_apps")
                                   value:[NSString stringWithFormat:@"%lu", (unsigned long)apps.count]]];
    [specifiers addObject:[self valueRow:SCILocalized(@"summary_tweaks")
                                   value:[NSString stringWithFormat:@"%lu", (unsigned long)tweaks.count]]];

    // ---- the apps something is changing
    PSSpecifier *appsGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_apps")
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
    [appsGroup setProperty:SCILocalized(@"apps_footer") forKey:@"footerText"];
    [specifiers addObject:appsGroup];

    if (!apps.count) {
        [specifiers addObject:[self noteRow:SCILocalized(@"apps_none")]];
    }
    for (SCIPanelApp *app in apps) {
        // A link rather than a label: this is the row that opens the switch, and 0.1.0
        // shipped these as plain text with nothing to tap, which made the whole page a
        // report about a device rather than a way to change it.
        PSSpecifier *row =
            [PSSpecifier preferenceSpecifierNamed:app.name
                                           target:self
                                              set:NULL
                                              get:NULL
                                           detail:NSClassFromString(@"SCIPanelAppController")
                                             cell:PSLinkCell
                                             edit:Nil];
        [row setProperty:[self tweakCount:app.tweaks.count] forKey:@"value"];

        // The identifier travels, not the object. The detail page looks the app up again
        // when it opens, so a tweak installed or removed in between is reflected rather
        // than remembered wrongly.
        [row setProperty:app.bundleIdentifier forKey:@"sciBundleIdentifier"];

        [specifiers addObject:row];
    }

    // ---- and the tweaks doing it
    PSSpecifier *tweaksGroup = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_tweaks")
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSGroupCell
                                                                edit:Nil];
    [tweaksGroup setProperty:SCILocalized(@"tweaks_footer") forKey:@"footerText"];
    [specifiers addObject:tweaksGroup];

    if (!tweaks.count) {
        [specifiers addObject:[self noteRow:SCILocalized(@"tweaks_none")]];
    }
    for (SCIPanelTweak *tweak in tweaks) {
        [specifiers addObject:[self valueRow:tweak.name value:[self reachOf:tweak apps:apps]]];
    }

    // ---- and what this version is honest about not doing
    PSSpecifier *about = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"section_about")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    [about setProperty:SCILocalized(@"about_readonly_note") forKey:@"footerText"];
    [specifiers addObject:about];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_version") value:SCIVersionString]];
    [specifiers addObject:[self valueRow:SCILocalized(@"about_author")
                                   value:SCILocalized(@"about_author_name")]];

    _specifiers = specifiers;
    return _specifiers;
}

/// How many apps this tweak reaches, said the way a person would.
- (NSString *)reachOf:(SCIPanelTweak *)tweak apps:(NSArray<SCIPanelApp *> *)apps {
    if (tweak.classes.count && !tweak.bundles.count && !tweak.executables.count) {
        return SCILocalized(@"targets_by_class");
    }
    if (tweak.targetsSystem && !tweak.executables.count) {
        return SCILocalized(@"targets_system");
    }

    NSUInteger reached = 0;
    for (SCIPanelApp *app in apps) {
        if ([app.tweaks containsObject:tweak]) reached++;
    }

    if (reached == 1) return SCILocalized(@"count_one_app");
    return [NSString stringWithFormat:SCILocalized(@"count_apps"), (unsigned long)reached];
}

- (NSString *)tweakCount:(NSUInteger)count {
    if (count == 1) return SCILocalized(@"count_one_tweak");
    return [NSString stringWithFormat:SCILocalized(@"count_tweaks"), (unsigned long)count];
}

/// A row with a value on the right and nothing to tap.
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

/// A row that is a sentence rather than a setting.
- (PSSpecifier *)noteRow:(NSString *)text {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:text
                                                      target:self
                                                         set:NULL
                                                         get:NULL
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"panel_title");
}

/// Rebuilt every time the page is shown, because a tweak can be installed or removed while
/// Settings is still open behind it.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

@end
