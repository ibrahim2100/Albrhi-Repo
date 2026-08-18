#import "SCITTStatus.h"
#import "SCITTReport.h"
#import "SCITTBadge.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import <objc/runtime.h>

///
/// The settings screen: the switches, and nothing else.
///
/// **What this redesign actually changed is what is *not* here.** The old screen had three
/// sections and fourteen of its rows were diagnostics -- accessor dumps, candidate chains, a gear
/// ladder, a method signature -- sitting as peers of the six switches somebody had opened the
/// screen to change. That is not a long screen, it is two screens interleaved: the part written
/// for the person using the tweak, and the part written for whoever is debugging it. They were
/// scrolled past each other every time.
///
/// So the diagnostics moved to `SCITTReport`, one row away under Advanced, and what is left is
/// grouped by the question a person came here with -- Download, Watching, Privacy, Protection --
/// rather than by which file owns the code. "Controls" was never a section; it was everything that
/// was not privacy.
///
/// Two structural things this file no longer does, both of which were quietly fragile:
///
///  - **A row's preference key travels on the switch itself**, as an associated object, instead of
///    a tag being mapped back to a key by a second `if` ladder further down the file. That ladder
///    was a parallel list, and this project has already paid for one of those: the origins array
///    that named every link's accessor one position off. A key that arrives with the control that
///    changed it cannot be looked up wrongly.
///  - **Rows are described once, in `-sections`**, and the table only renders them. Adding a
///    switch is one entry, not an entry plus a row count plus a branch in two methods.
///

static NSString *const kSCIKindSwitch = @"switch";
static NSString *const kSCIKindLink = @"link";

static NSString *const kSCIRowKind = @"kind";
static NSString *const kSCIRowTitle = @"title";
static NSString *const kSCIRowNote = @"note";
static NSString *const kSCIRowIcon = @"icon";
static NSString *const kSCIRowColor = @"color";
static NSString *const kSCIRowPref = @"pref";
static NSString *const kSCIRowWarns = @"warns";

static NSString *const kSCISectionTitle = @"section";
static NSString *const kSCISectionRows = @"rows";

/// The preference key a switch changes, carried by the switch.
static const void *kSCIPrefKeyAssoc = &kSCIPrefKeyAssoc;

@interface SCITTStatus ()
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;
@end

@implementation SCITTStatus

+ (void)present {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) window = candidate;
        }
    }
    if (!window) return;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        if ([top.presentedViewController isKindOfClass:[UINavigationController class]] &&
            [[(UINavigationController *)top.presentedViewController topViewController]
                isKindOfClass:[SCITTStatus class]]) {
            return;
        }
        top = top.presentedViewController;
    }
    if (!top) return;

    SCITTStatus *status = [[SCITTStatus alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *host =
        [[UINavigationController alloc] initWithRootViewController:status];
    host.modalPresentationStyle = UIModalPresentationPageSheet;

    // The tint carries through to every screen pushed onto this stack, so the report screen's own
    // Copy button and back chevron come out in the tweak's colour without setting it twice.
    host.view.tintColor = SCIAccent();
    [top presentViewController:host animated:YES completion:nil];
}

#pragma mark - The rows

/// Every row on this screen, named once.
- (NSArray<NSDictionary *> *)buildSections {
    return @[
        @{
            kSCISectionTitle: SCILocalized(@"section_download"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefDownloadButton,
                    kSCIRowTitle: SCILocalized(@"row_download_button"),
                    kSCIRowNote: SCILocalized(@"row_download_button_note"),
                    kSCIRowIcon: @"arrow.down",
                    kSCIRowColor: SCIAccent(),
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPhotoDownload,
                    kSCIRowTitle: SCILocalized(@"row_photo_download"),
                    kSCIRowNote: SCILocalized(@"row_photo_download_note"),
                    kSCIRowIcon: @"photo.on.rectangle.angled",
                    kSCIRowColor: [UIColor systemPinkColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPhotoAudio,
                    kSCIRowTitle: SCILocalized(@"row_photo_audio"),
                    kSCIRowNote: SCILocalized(@"row_photo_audio_note"),
                    kSCIRowIcon: @"music.note",
                    kSCIRowColor: [UIColor systemPurpleColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefExternalHD,
                    kSCIRowTitle: SCILocalized(@"row_external_hd"),
                    kSCIRowNote: SCILocalized(@"row_external_hd_note"),
                    kSCIRowIcon: @"antenna.radiowaves.left.and.right",
                    kSCIRowColor: [UIColor systemOrangeColor],
                    // **The one row on this screen whose note is drawn in a warning colour, and it
                    // is not decoration.** Turning it on tells a service outside TikTok which video
                    // is being watched -- the exact thing the three privacy switches below exist to
                    // stop. A cost paid by the person using this is a cost they have to be able to
                    // see before they pay it, and a grey note under a switch does not read as a
                    // cost. Nothing else here earns this treatment; if a second row ever does, that
                    // is a reason to re-read what it does, not to reuse the styling.
                    kSCIRowWarns: @YES,
                },
            ],
        },
        @{
            kSCISectionTitle: SCILocalized(@"section_watching"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefHideAds,
                    kSCIRowTitle: SCILocalized(@"row_ads"),
                    kSCIRowNote: SCILocalized(@"row_ads_note"),
                    kSCIRowIcon: @"nosign",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefProgressBar,
                    kSCIRowTitle: SCILocalized(@"row_progress_bar"),
                    kSCIRowNote: SCILocalized(@"row_progress_bar_note"),
                    kSCIRowIcon: @"slider.horizontal.below.rectangle",
                    kSCIRowColor: [UIColor systemBlueColor],
                },
            ],
        },
        @{
            // Three switches, not one. A story's seen mark, a message's read receipt and a profile
            // view are three reports to three different places, and one switch bundling them could
            // never be turned off for just one.
            kSCISectionTitle: SCILocalized(@"section_privacy"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPrivacyStory,
                    kSCIRowTitle: SCILocalized(@"row_privacy_story"),
                    kSCIRowNote: SCILocalized(@"row_privacy_story_note"),
                    kSCIRowIcon: @"eye.slash.fill",
                    kSCIRowColor: [UIColor systemTealColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPrivacyMessages,
                    kSCIRowTitle: SCILocalized(@"row_privacy_messages"),
                    kSCIRowNote: SCILocalized(@"row_privacy_messages_note"),
                    kSCIRowIcon: @"message.fill",
                    kSCIRowColor: [UIColor systemTealColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefPrivacyProfile,
                    kSCIRowTitle: SCILocalized(@"row_privacy_profile"),
                    kSCIRowNote: SCILocalized(@"row_privacy_profile_note"),
                    kSCIRowIcon: @"person.fill.questionmark",
                    kSCIRowColor: [UIColor systemTealColor],
                },
            ],
        },
        @{
            // Its own section rather than a row under Watching: these two do not change what TikTok
            // shows, they change what a tap does -- the only feature here that stands between the
            // user and an action they are already making.
            kSCISectionTitle: SCILocalized(@"section_confirm"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmLike,
                    kSCIRowTitle: SCILocalized(@"row_confirm_like"),
                    kSCIRowNote: SCILocalized(@"row_confirm_like_note"),
                    kSCIRowIcon: @"heart.fill",
                    kSCIRowColor: [UIColor systemRedColor],
                },
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefConfirmFollow,
                    kSCIRowTitle: SCILocalized(@"row_confirm_follow"),
                    kSCIRowNote: SCILocalized(@"row_confirm_follow_note"),
                    kSCIRowIcon: @"person.badge.plus",
                    kSCIRowColor: [UIColor systemPinkColor],
                },
            ],
        },
        @{
            kSCISectionTitle: SCILocalized(@"section_protection"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefBypass,
                    kSCIRowTitle: SCILocalized(@"row_bypass"),
                    kSCIRowNote: SCILocalized(@"row_bypass_note"),
                    kSCIRowIcon: @"shield.lefthalf.filled",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
            ],
        },
        @{
            kSCISectionTitle: SCILocalized(@"section_advanced"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindLink,
                    kSCIRowTitle: SCILocalized(@"row_report"),
                    kSCIRowNote: SCILocalized(@"row_report_note"),
                    kSCIRowIcon: @"stethoscope",
                    kSCIRowColor: [UIColor systemGrayColor],
                },
            ],
        },
    ];
}

#pragma mark - Screen

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"title");
    self.sections = [self buildSections];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(dismissSelf)];

    // **No copy button up here, on request, and the reasoning that put one here was wrong.** It was
    // added so a report could be sent without finding the right screen first -- but a share glyph in
    // the corner of a settings screen says nothing about what it shares, and the thing it copies is
    // the report, which now has a screen of its own with a Copy button that is labelled. One button,
    // where its meaning is obvious.
    self.tableView.sectionHeaderTopPadding = 0;

    // Every row carries a wrapped note under its title. Without an automatic height the cell is
    // clamped to the table's 44-point default and a two-line note is drawn over the row below
    // rather than pushing it down -- a real reported bug on this screen, fixed here once.
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;

    [self buildHeader];
    [self buildFooter];
}

/// The card at the top: what this is, which TikTok it is running in, and whether the three moving
/// parts found their classes in *this* build -- read live, so the card cannot disagree with the app.
- (void)buildHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectZero];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [header addSubview:card];

    // The mark: the download glyph on an accent disc, which is the same shape and the same arrow
    // as the button in the feed and the icon on the saving banner. Three places, one identity --
    // the previous mark was a music note, which is TikTok's own symbol rather than this tweak's.
    UIView *mark = [[UIView alloc] init];
    mark.backgroundColor = SCIAccent();
    mark.layer.cornerRadius = 13;
    mark.layer.cornerCurve = kCACornerCurveContinuous;
    mark.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *markGlyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22
                                                                                 weight:UIImageSymbolWeightBold]]];
    markGlyph.tintColor = [UIColor whiteColor];
    markGlyph.translatesAutoresizingMaskIntoConstraints = NO;
    [mark addSubview:markGlyph];

    UILabel *name = [[UILabel alloc] init];
    name.text = SCILocalized(@"title");
    name.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    name.textColor = [UIColor labelColor];
    name.numberOfLines = 0;

    UILabel *version = [[UILabel alloc] init];
    version.text = [NSString stringWithFormat:@"%@ · TikTok %@", SCIVersionString,
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];
    version.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    version.textColor = [UIColor secondaryLabelColor];

    UIStackView *titles = [[UIStackView alloc] initWithArrangedSubviews:@[name, version]];
    titles.axis = UILayoutConstraintAxisVertical;
    titles.spacing = 2;

    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[mark, titles]];
    top.axis = UILayoutConstraintAxisHorizontal;
    top.spacing = 12;
    top.alignment = UIStackViewAlignmentCenter;

    UIStackView *pills = [[UIStackView alloc] init];
    pills.axis = UILayoutConstraintAxisHorizontal;
    pills.spacing = 8;
    pills.distribution = UIStackViewDistributionFillEqually;

    BOOL adsFilter = NSClassFromString(@"AWEAwemeModel") != nil;
    BOOL button = NSClassFromString(@"TTKFeedInteractionStackView") != nil
        || NSClassFromString(@"TTKFeedRightInteractionStackView") != nil;
    BOOL bypass = NSClassFromString(@"TTAdSplashDeviceHelper") != nil;

    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_ads") on:adsFilter]];
    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_button") on:button]];
    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_bypass") on:bypass]];

    NSMutableArray<UIView *> *pieces = [NSMutableArray arrayWithObjects:top, pills, nil];

    // **The panel switch, at the top, in red, and only when it is off.**
    //
    // It used to be the first row of the Status section -- so the one fact that explains why every
    // switch on this screen is doing nothing sat below fourteen diagnostic rows, on a screen most
    // people would never scroll to the bottom of. A tweak standing down because it was never
    // opted into looks exactly like a tweak that is broken, and this is the sentence that tells
    // the two apart. When the gate is on it says nothing at all: a banner that is always there is
    // read as decoration.
    if (!SCIPanelAllowsThisApp()) [pieces addObject:[self gateWarning]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:pieces];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [mark.widthAnchor constraintEqualToConstant:46],
        [mark.heightAnchor constraintEqualToConstant:46],
        [markGlyph.centerXAnchor constraintEqualToAnchor:mark.centerXAnchor],
        [markGlyph.centerYAnchor constraintEqualToAnchor:mark.centerYAnchor],

        [card.topAnchor constraintEqualToAnchor:header.topAnchor constant:4],
        [card.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [card.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [card.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-14],

        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];

    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    header.frame = CGRectMake(0, 0, width,
        [header systemLayoutSizeFittingSize:CGSizeMake(width, 0)
              withHorizontalFittingPriority:UILayoutPriorityRequired
                    verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height);

    self.tableView.tableHeaderView = header;
}

- (UIView *)gateWarning {
    UIView *banner = [[UIView alloc] init];
    banner.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.14];
    banner.layer.cornerRadius = 12;
    banner.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"exclamationmark.triangle.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14
                                                                                 weight:UIImageSymbolWeightBold]]];
    icon.tintColor = [UIColor systemRedColor];
    [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *label = [[UILabel alloc] init];
    label.text = SCILocalized(@"gate_off");
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    label.textColor = [UIColor systemRedColor];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [banner addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:banner.topAnchor constant:10],
        [row.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-10],
        [row.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:12],
        [row.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-12],
    ]];

    return banner;
}

- (UIView *)pillWithTitle:(NSString *)title on:(BOOL)on {
    UIView *pill = [[UIView alloc] init];
    pill.backgroundColor = [(on ? [UIColor systemGreenColor] : [UIColor systemRedColor])
        colorWithAlphaComponent:0.15];
    pill.layer.cornerRadius = 10;
    pill.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageView *dot = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:(on ? @"checkmark.circle.fill" : @"xmark.circle.fill")
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11
                                                                                 weight:UIImageSymbolWeightBold]]];
    dot.tintColor = on ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [dot setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    label.textColor = on ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[dot, label]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 4;
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [pill addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:pill.topAnchor constant:7],
        [row.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-7],
        [row.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:9],
        [row.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-9],
    ]];

    return pill;
}

/// **The reference credits are not on this screen, on request, and that is a licence question worth
/// being explicit about rather than a matter of taste.**
///
/// TikTok's four references -- BandarHL's and al3raQe's BHTikTok, NA9 For TikTok and VibeTok -- carry
/// no licence at all, and nothing was copied from any of them: they were read for *where* TikTok is
/// hookable, which is a fact about TikTok. There is no obligation attached to a fact, so naming them
/// in the repository, the changelog and CLAUDE.md is where it belongs, and a settings screen is not
/// a bibliography.
///
/// **The Instagram tweak is the opposite case and nothing here applies to it.** It is derived from
/// SCInsta under GPLv3, so its in-app credit is a term of the licence -- not a courtesy, and never
/// removable on the same reasoning that removed this one.
///
/// The footer stays as a method rather than being deleted so the table keeps a little breathing room
/// under its last section instead of ending flush against the edge.
- (void)buildFooter {
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    self.tableView.tableFooterView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 28)];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// `-copyReport` was here, and it is deleted rather than left unreachable: a method nobody calls
// is a claim its button still exists. The report's own screen owns copying now.

#pragma mark - Table

- (NSDictionary *)rowAt:(NSIndexPath *)indexPath {
    if (indexPath.section < 0 || indexPath.section >= (NSInteger)self.sections.count) return nil;
    NSArray *rows = self.sections[(NSUInteger)indexPath.section][kSCISectionRows];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)rows.count) return nil;
    return rows[(NSUInteger)indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.sections.count) return 0;
    return (NSInteger)[self.sections[(NSUInteger)section][kSCISectionRows] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.sections.count) return nil;
    return self.sections[(NSUInteger)section][kSCISectionTitle];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    NSDictionary *row = [self rowAt:indexPath];
    if (!row) return cell;

    cell.textLabel.text = row[kSCIRowTitle];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];

    cell.detailTextLabel.text = row[kSCIRowNote];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [row[kSCIRowWarns] boolValue]
        ? [UIColor systemOrangeColor]
        : [UIColor secondaryLabelColor];

    cell.imageView.image = SCITTBadgeImage(row[kSCIRowIcon], row[kSCIRowColor]);

    if ([row[kSCIRowKind] isEqualToString:kSCIKindLink]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = SCIAccent();
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:row[kSCIRowPref]];

    // The key rides on the control, so the handler cannot mistake which preference was changed.
    objc_setAssociatedObject(toggle, kSCIPrefKeyAssoc, row[kSCIRowPref],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [toggle addTarget:self
               action:@selector(toggled:)
     forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;

    return cell;
}

- (void)toggled:(UISwitch *)toggle {
    NSString *key = objc_getAssociatedObject(toggle, kSCIPrefKeyAssoc);
    if (![key isKindOfClass:[NSString class]]) return;
    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *row = [self rowAt:indexPath];
    if (![row[kSCIRowKind] isEqualToString:kSCIKindLink]) return;

    SCITTReport *report = [[SCITTReport alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:report animated:YES];
}

@end
