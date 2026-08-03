#import "SCIYTSettingsController.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCIYTDiagnostics.h"
#import "../Features/Download/SCIYTDownload.h"
#import "../Features/Download/Center/SCIYTDownloadCenter.h"
#import <objc/runtime.h>

/// YouTube's red. Written out rather than read from YTCommonColorPalette: one colour is
/// not worth a dependency on a class whose shape has not been verified, and unverified
/// dependencies are what the last three releases were about.
static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

///
/// One row. A plain object rather than a subclass per kind, because the difference
/// between a switch row and a disclosure row is one field, not one class.
///
typedef NS_ENUM(NSInteger, SCIRowKind) {
    SCIRowKindSwitch,
    SCIRowKindDisclosure,
};

@interface SCIRow : NSObject
@property (nonatomic, assign) SCIRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *prefKey;      ///< switch rows only
@property (nonatomic, copy) void (^action)(void);   ///< disclosure rows only
@end

@implementation SCIRow

+ (instancetype)switchRow:(NSString *)title
                   detail:(NSString *)detail
                   symbol:(NSString *)symbol
                  prefKey:(NSString *)prefKey {
    SCIRow *row = [[SCIRow alloc] init];
    row.kind = SCIRowKindSwitch;
    row.title = title;
    row.detail = detail;
    row.symbol = symbol;
    row.prefKey = prefKey;
    return row;
}

+ (instancetype)disclosureRow:(NSString *)title
                       detail:(NSString *)detail
                       symbol:(NSString *)symbol
                       action:(void (^)(void))action {
    SCIRow *row = [[SCIRow alloc] init];
    row.kind = SCIRowKindDisclosure;
    row.title = title;
    row.detail = detail;
    row.symbol = symbol;
    row.action = action;
    return row;
}

@end


@interface SCISection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, strong) NSArray<SCIRow *> *rows;
@end

@implementation SCISection
@end


@interface SCIYTSettingsController ()
@property (nonatomic, strong) NSArray<SCISection *> *sections;
@end

@implementation SCIYTSettingsController

- (instancetype)init {
    // Inset-grouped: the same shape as the settings panel on this repository's
    // Instagram side, so the two tweaks read as one project.
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"panel_title");
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.tableView.tableHeaderView = [self identityHeader];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                      target:self
                                                      action:@selector(close)];

    [self buildSections];
}

// Declared here, defined further down beside the picker they belong to. Objective-C methods
// may be called before they appear in the same @implementation; plain C functions may not,
// and -buildSections uses both of these to label the rows.
static NSArray<NSNumber *> *SCIQualityCaps(void);
static NSString *SCIQualityLabel(NSInteger cap);

- (void)buildSections {
    __weak __typeof(self) weakSelf = self;

    SCISection *ads = [[SCISection alloc] init];
    ads.title = SCILocalized(@"section_ads");
    ads.rows = @[
        [SCIRow switchRow:SCILocalized(@"hide_ads")
                   detail:SCILocalized(@"hide_ads_note")
                   symbol:@"hand.raised.fill"
                  prefKey:SCIPrefHideAds],
        [SCIRow switchRow:SCILocalized(@"hide_paid_promotion")
                   detail:SCILocalized(@"hide_paid_promotion_note")
                   symbol:@"megaphone.fill"
                  prefKey:SCIPrefHidePaidPromo],
    ];

    // Quality. Two ceilings and a switch.
    //
    // The caps are their own rows rather than one "data saver" switch because the two
    // connections are not one decision: a phone on home Wi-Fi and the same phone on a
    // metered plan abroad want different answers, and a single switch makes you choose
    // which of the two to be wrong about.
    SCISection *quality = [[SCISection alloc] init];
    quality.title = SCILocalized(@"section_quality");
    quality.footer = SCILocalized(@"set_cap_note");
    quality.rows = @[
        [SCIRow disclosureRow:SCILocalized(@"set_cap_wifi")
                       detail:SCIQualityLabel(SCIPrefNumber(SCIPrefCapWiFi))
                       symbol:@"wifi"
                       action:^{ [weakSelf pickCapFor:SCIPrefCapWiFi]; }],
        [SCIRow disclosureRow:SCILocalized(@"set_cap_cellular")
                       detail:SCIQualityLabel(SCIPrefNumber(SCIPrefCapCellular))
                       symbol:@"antenna.radiowaves.left.and.right"
                       action:^{ [weakSelf pickCapFor:SCIPrefCapCellular]; }],
        [SCIRow switchRow:SCILocalized(@"set_classic_quality")
                   detail:SCILocalized(@"set_classic_quality_note")
                   symbol:@"list.bullet"
                  prefKey:SCIPrefClassicQuality],
    ];

    SCISection *player = [[SCISection alloc] init];
    player.title = SCILocalized(@"section_player");
    player.rows = @[
        [SCIRow switchRow:SCILocalized(@"background_playback")
                   detail:SCILocalized(@"background_playback_note")
                   symbol:@"speaker.wave.2.fill"
                  prefKey:SCIPrefBackgroundPlay],
    ];

    // Downloads. The centre itself is the first row rather than a setting, because it is
    // the thing someone opening this screen after saving a video came looking for.
    SCISection *downloads = [[SCISection alloc] init];
    downloads.title = SCILocalized(@"set_downloads_title");
    downloads.rows = @[
        [SCIRow disclosureRow:SCILocalized(@"set_open_centre")
                       detail:nil
                       symbol:@"arrow.down.circle.fill"
                       action:^{ [SCIYTDownloadCenter present]; }],
        [SCIRow switchRow:SCILocalized(@"set_tab_button")
                   detail:nil
                   symbol:@"square.grid.2x2"
                  prefKey:SCIPrefTabButton],
        [SCIRow switchRow:SCILocalized(@"set_auto_photos")
                   detail:SCILocalized(@"set_auto_photos_note")
                   symbol:@"photo.on.rectangle"
                  prefKey:SCIPrefAutoPhotos],
    ];

    // Two sections: the switch that turns it on, and the categories it governs. Split
    // because "skip sponsored parts" is one decision and "which parts count" is eight
    // more, and a single list of nine switches reads as nine equal choices.
    SCISection *sponsor = [[SCISection alloc] init];
    sponsor.title = SCILocalized(@"section_sponsorblock");
    sponsor.rows = @[
        [SCIRow switchRow:SCILocalized(@"sponsorblock")
                   detail:SCILocalized(@"sponsorblock_note")
                   symbol:@"forward.end.fill"
                  prefKey:SCIPrefSponsorBlock],
        [SCIRow switchRow:SCILocalized(@"sponsorblock_notice")
                   detail:SCILocalized(@"sponsorblock_notice_note")
                   symbol:@"bubble.left.fill"
                  prefKey:SCIPrefSBNotice],
        [SCIRow switchRow:SCILocalized(@"sponsorblock_markers")
                   detail:SCILocalized(@"sponsorblock_markers_note")
                   symbol:@"paintpalette.fill"
                  prefKey:SCIPrefSBMarkers],
    ];

    SCISection *categories = [[SCISection alloc] init];
    categories.title = SCILocalized(@"sb_categories");
    categories.rows = @[
        [SCIRow switchRow:SCILocalized(@"sb_sponsor")
                   detail:SCILocalized(@"sb_sponsor_note")
                   symbol:@"dollarsign.circle.fill"
                  prefKey:SCIPrefSBSponsor],
        [SCIRow switchRow:SCILocalized(@"sb_selfpromo")
                   detail:SCILocalized(@"sb_selfpromo_note")
                   symbol:@"person.crop.circle.fill"
                  prefKey:SCIPrefSBSelfPromo],
        [SCIRow switchRow:SCILocalized(@"sb_interaction")
                   detail:SCILocalized(@"sb_interaction_note")
                   symbol:@"hand.thumbsup.fill"
                  prefKey:SCIPrefSBInteraction],
        [SCIRow switchRow:SCILocalized(@"sb_intro")
                   detail:SCILocalized(@"sb_intro_note")
                   symbol:@"film.fill"
                  prefKey:SCIPrefSBIntro],
        [SCIRow switchRow:SCILocalized(@"sb_outro")
                   detail:SCILocalized(@"sb_outro_note")
                   symbol:@"rectangle.stack.fill"
                  prefKey:SCIPrefSBOutro],
        [SCIRow switchRow:SCILocalized(@"sb_preview")
                   detail:SCILocalized(@"sb_preview_note")
                   symbol:@"text.bubble.fill"
                  prefKey:SCIPrefSBPreview],
        [SCIRow switchRow:SCILocalized(@"sb_filler")
                   detail:SCILocalized(@"sb_filler_note")
                   symbol:@"scissors"
                  prefKey:SCIPrefSBFiller],
        [SCIRow switchRow:SCILocalized(@"sb_music_offtopic")
                   detail:SCILocalized(@"sb_music_offtopic_note")
                   symbol:@"music.note"
                  prefKey:SCIPrefSBMusicOffTopic],
    ];
    // Where the data comes from, its licence, and what does and does not leave the
    // phone. The attribution is a condition of CC BY-NC-SA; the privacy sentence is
    // there because a feature that talks to a server should say so where it is switched
    // on, not in a changelog.
    categories.footer = SCILocalized(@"sb_credit");

    SCISection *general = [[SCISection alloc] init];
    general.title = SCILocalized(@"section_general");
    general.rows = @[
        [SCIRow switchRow:SCILocalized(@"block_update_nag")
                   detail:SCILocalized(@"block_update_nag_note")
                   symbol:@"bell.slash.fill"
                  prefKey:SCIPrefBlockUpdateNag],
        [SCIRow switchRow:SCILocalized(@"verbose_logging")
                   detail:SCILocalized(@"verbose_logging_note")
                   symbol:@"text.alignleft"
                  prefKey:SCIPrefVerboseLogging],
        [SCIRow disclosureRow:SCILocalized(@"dl_row")
                       detail:SCILocalized(@"dl_row_note")
                       symbol:@"arrow.down.circle.fill"
                       action:^{ [SCIYTDownload presentFrom:weakSelf]; }],
        [SCIRow disclosureRow:SCILocalized(@"diagnostics")
                       detail:SCILocalized(@"diagnostics_note")
                       symbol:@"stethoscope"
                       action:^{
            [weakSelf openDiagnostics];
        }],
    ];

    // How to get back here. A two-finger long press is safe and reliable and completely
    // undiscoverable, which is the trade it makes.
    general.footer = SCILocalized(@"panel_subtitle");

    self.sections = @[downloads, quality, ads, player, sponsor, categories, general];
}

/// The ceilings offered, highest first, with "no limit" as the default.
///
/// Real resolutions, not menu positions: the stored value is 1080 rather than "the third
/// one down", so reordering this list can never quietly change what someone chose.
static NSArray<NSNumber *> *SCIQualityCaps(void) {
    return @[@0, @2160, @1440, @1080, @720, @480, @360, @144];
}

static NSString *SCIQualityLabel(NSInteger cap) {
    if (cap <= 0) return SCILocalized(@"quality_auto");
    return [NSString stringWithFormat:SCILocalized(@"quality_cap_format"), (long)cap];
}

- (void)pickCapFor:(NSString *)key {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"set_cap_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    for (NSNumber *cap in SCIQualityCaps()) {
        UIAlertAction *choice =
            [UIAlertAction actionWithTitle:SCIQualityLabel(cap.integerValue)
                                     style:UIAlertActionStyleDefault
                                   handler:^(__unused UIAlertAction *action) {
                [[NSUserDefaults standardUserDefaults] setInteger:cap.integerValue forKey:key];

                // Rebuilt, not just reloaded: the row's subtitle is the chosen value, and
                // it is made when the section is made.
                [weakSelf buildSections];
                [weakSelf.tableView reloadData];
            }];
        [sheet addAction:choice];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // Required on iPad, and harmless on a phone. Without it the sheet has nothing to point
    // at and UIKit raises rather than guessing.
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);

    [self presentViewController:sheet animated:YES completion:nil];
}

///
/// The identity card, and it reports its own health.
///
/// The badge reads the runtime, not a constant: if the classes the features hook are
/// not there, it says so here, at the top, before anything else is read. Every earlier
/// version put that answer somewhere the user had to go looking for -- and in 0.1.0 it
/// was behind the very thing that had failed.
///
- (UIView *)identityHeader {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 108)];

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, 12, 0, 84)];
    card.backgroundColor = [SCIAccent() colorWithAlphaComponent:0.10];
    card.layer.borderColor = [SCIAccent() colorWithAlphaComponent:0.28].CGColor;
    card.layer.borderWidth = 0.5;
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    // Sized by the autoresizing mask rather than by constraints. A table header is laid
    // out by the table, which sets its width and asks nothing else of it, so a mask is
    // both sufficient and impossible to over-constrain.
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [host addSubview:card];

    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(14, 20, 44, 44)];
    badge.backgroundColor = SCIAccent();
    badge.layer.cornerRadius = 13;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:badge];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(11, 11, 22, 22)];
    icon.image = [UIImage systemImageNamed:@"play.rectangle.fill"];
    icon.tintColor = UIColor.whiteColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [badge addSubview:icon];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(70, 22, 200, 20)];
    name.text = SCILocalized(@"panel_title");
    name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    name.textColor = UIColor.whiteColor;
    [card addSubview:name];

    UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(70, 42, 220, 18)];
    version.text = [NSString stringWithFormat:@"%@ · %@ %@",
        SCIVersionString, SCILocalized(@"diag_app_version"), [SCIYTDiagnostics appVersion]];
    version.font = [UIFont systemFontOfSize:12];
    version.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.6];
    [card addSubview:version];

    BOOL healthy = [SCIYTDiagnostics featuresAttached];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(70, 60, 220, 16)];
    status.text = healthy ? SCILocalized(@"identity_attached") : SCILocalized(@"identity_partial");
    status.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    status.textColor = healthy ? [UIColor colorWithRed:0.36 green:0.79 blue:0.65 alpha:1.0]
                              : [UIColor colorWithRed:0.94 green:0.62 blue:0.15 alpha:1.0];
    [card addSubview:status];

    return host;
}

// MARK: - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].title;
}

/// Under the last section, so how to get back here is written down somewhere the user
/// will actually be when they wonder. A two-finger long press is safe and reliable and
/// completely undiscoverable, which is the trade it makes.
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    // Carried on the section rather than worked out here. Matching on a row count was
    // the first version of this and it is the kind of thing that breaks the day a ninth
    // category is added -- silently, by attaching the licence notice to the wrong list.
    return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIRow *row = self.sections[indexPath.section].rows[indexPath.row];

    // Built fresh rather than dequeued. These are a handful of rows on a screen opened
    // occasionally, and reuse is where a switch ends up wired to the wrong preference.
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                  reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];

    cell.textLabel.text = row.title;
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont systemFontOfSize:15];

    cell.detailTextLabel.text = row.detail;
    cell.detailTextLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.55];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11.5];
    cell.detailTextLabel.numberOfLines = 0;

    cell.imageView.image = [UIImage systemImageNamed:row.symbol];
    cell.imageView.tintColor = [UIColor.whiteColor colorWithAlphaComponent:0.55];

    if (row.kind == SCIRowKindSwitch) {
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.onTintColor = SCIAccent();
        toggle.on = SCIPrefEnabled(row.prefKey);

        // The key travels with the control, so the handler cannot read one preference
        // and write another.
        objc_setAssociatedObject(toggle, @selector(prefKey), row.prefKey,
                                 OBJC_ASSOCIATION_RETAIN);
        [toggle addTarget:self
                   action:@selector(toggled:)
         forControlEvents:UIControlEventValueChanged];

        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SCIRow *row = self.sections[indexPath.section].rows[indexPath.row];
    if (row.action) row.action();
}

// MARK: - Actions

- (void)toggled:(UISwitch *)toggle {
    NSString *key = objc_getAssociatedObject(toggle, @selector(prefKey));
    if (!key.length) return;

    [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:key];
    SCILogV(@"settings: %@ = %@", key, toggle.isOn ? @"on" : @"off");
}

- (void)openDiagnostics {
    // Wrapped for the same reason the panel itself is: this page reads objects
    // YouTube gave us and prints them, and it went unguarded while the panel around
    // it was protected. The report is still on disk either way, which is the point
    // of writing it there.
    UIViewController *page = nil;

    @try {
        page = [SCIYTDiagnostics viewController];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordPanelFailure:
            [NSString stringWithFormat:@"diagnostics page: %@", exception.reason]];
        SCILogV(@"diagnostics page could not be built: %@", exception.reason);
    }

    if (!page) {
        // Says where the report is rather than failing silently — the file is the
        // way out when the page is not.
        NSString *path = [SCIYTDiagnostics writeReportToFile];

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:SCILocalized(@"diag_title")
                             message:[NSString stringWithFormat:SCILocalized(@"diag_page_failed"),
                                      path ?: @"Documents/AlbrhiYT-report.txt"]
                      preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [self.navigationController pushViewController:page animated:YES];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Presentation

+ (UIViewController *)topMostController {
    UIWindow *key = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { key = window; break; }
        }
        if (key) break;
    }

    UIViewController *controller = key.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

+ (void)present {
    UIViewController *host = [self topMostController];
    if (!host) {
        SCILogV(@"settings: nothing to present from");
        return;
    }

    if (host.isBeingPresented || host.isBeingDismissed) {
        SCILogV(@"settings: host is mid-transition, not presenting");
        return;
    }

    // The guard stays even though a table view is far less likely to throw than the
    // hand-built panel it replaces. It is not there because this code is expected to
    // fail; it is there because a tweak whose job is to report what is happening must
    // never be the reason the app stops.
    @try {
        SCIYTSettingsController *settings = [[SCIYTSettingsController alloc] init];
        UINavigationController *nav =
            [[UINavigationController alloc] initWithRootViewController:settings];

        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        nav.navigationBar.barStyle = UIBarStyleBlack;
        nav.navigationBar.tintColor = SCIAccent();

        // Forced inside the guard, so a layout fault lands here rather than later
        // inside UIKit's transition where it would be out of reach.
        (void)settings.view;

        [host presentViewController:nav animated:YES completion:nil];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordPanelFailure:
            [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];

        NSLog(@"[AlbrhiYT] the settings screen could not be built: %@ — %@",
              exception.name, exception.reason);
    }
}

@end
