#import "SCIPanelGuideController.h"
#import <Preferences/PSSpecifier.h>

#import "SCIPanelScan.h"
#import "SCIPanelBadge.h"
#import "Localization/SCILocalize.h"

@implementation SCIPanelGuideController

//
// One line per tweak, keyed by the dylib's own name.
//
// Written as literal keys rather than composed at runtime -- `SCILocalized([@"guide_desc_"
// stringByAppendingString:name])` would read the same and would be invisible to check.py's
// localization rules, which is how a table loses a translation without anything failing.
//
- (NSString *)descriptionForTweak:(NSString *)name {
    static NSDictionary *table = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"Albrhi":        SCILocalized(@"guide_desc_instagram"),
            @"AlbrhiYT":      SCILocalized(@"guide_desc_youtube"),
            @"AlbrhiTW":      SCILocalized(@"guide_desc_twitter"),
            @"AlbrhiTT":      SCILocalized(@"guide_desc_tiktok"),
            @"AlbrhiSpotify": SCILocalized(@"guide_desc_spotify"),
            @"AlbrhiYTM":     SCILocalized(@"guide_desc_ytmusic"),
            @"AlbrhiNU":      SCILocalized(@"guide_desc_nextup"),
            @"AlbrhiWatch":   SCILocalized(@"guide_desc_watch"),
        };
    });

    // A tweak this page has never been told about still gets a row, saying so. Silence would
    // read as "this one does nothing".
    return table[name] ?: SCILocalized(@"guide_desc_unknown");
}

// The same row the main page draws, built the same way on purpose.
//
// The first draft of this used PSStaticTextCell with a "staticTextMessage" -- which renders a
// paragraph, not a title beside a value -- and set three properties hoping one would land. The
// panel already had a working title-and-value row; copying it is the whole fix.
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

/// A row that shows what it was given and cannot be edited.
- (id)fixedValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"value"] ?: @"";
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *specifiers = [NSMutableArray array];

    PSSpecifier *intro = [PSSpecifier preferenceSpecifierNamed:@""
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    [intro setProperty:SCILocalized(@"guide_intro") forKey:@"footerText"];
    [specifiers addObject:intro];

    NSArray<SCIPanelEntry *> *entries = [SCIPanelScan entries];

    // One tweak, one group: its name as the header, the version facts as its rows, and what it
    // does as the footer. A single flat list would put a description and a version number in
    // the same row and make both harder to read than either alone.
    for (SCIPanelEntry *entry in entries) {
        PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:entry.appName
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSGroupCell
                                                              edit:Nil];
        [group setProperty:[self descriptionForTweak:entry.tweakName] forKey:@"footerText"];
        [specifiers addObject:group];

        [specifiers addObject:[self valueRow:SCILocalized(@"guide_tested")
                                       value:entry.testedVersion.length
                                                 ? entry.testedVersion
                                                 : SCILocalized(@"versions_unknown")]];

        // **"Not installed" is an answer, and a blank is not.** An app that is absent explains
        // a row that does nothing far better than an empty version does.
        [specifiers addObject:[self valueRow:SCILocalized(@"guide_installed")
                                       value:entry.appInstalled
                                                 ? (entry.appVersion.length ? entry.appVersion
                                                                            : SCILocalized(@"versions_unknown"))
                                                 : SCILocalized(@"versions_not_installed")]];
    }

    if (!entries.count) {
        PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"apps_none")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSGroupCell
                                                             edit:Nil];
        [specifiers addObject:none];
    }

    // Assigned to the ivar, never only returned. PSListController reads _specifiers directly in
    // places an override's return value never reaches, and a page that skipped this shipped as
    // a black screen once already.
    _specifiers = specifiers;
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = SCILocalized(@"guide_title");
}

@end
