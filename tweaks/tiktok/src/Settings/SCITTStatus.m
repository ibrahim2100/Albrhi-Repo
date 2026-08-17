#import "SCITTStatus.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCITTDiagnostics.h"
#import "../Features/Download/SCITTMedia.h"
#import "../Features/Download/SCITTDownload.h"
#import "../Features/Download/SCITTButton.h"

///
/// A real grouped settings screen, in sections -- not a stack of switches with one
/// report dumped underneath. Controls, then Privacy as its own section (a story seen, a
/// message read and a profile view are three different reports to three different
/// places, and one switch bundling all three could never be turned off for just one of
/// them), then what has been captured, then the numbers behind each feature -- the same
/// shape the X tweak's own settings screen (SCITWSettings.m) already settled on.
///

static const NSInteger kSCISectionControls = 0;
static const NSInteger kSCISectionPrivacy = 1;
static const NSInteger kSCISectionDownload = 2;
static const NSInteger kSCISectionStatus = 3;
static const NSInteger kSCISectionCount = 4;

static const NSInteger kSCIRowAds = 0;
static const NSInteger kSCIRowDownloadButton = 1;
static const NSInteger kSCIRowBypass = 2;
static const NSInteger kSCIControlsRowCount = 3;

static const NSInteger kSCIRowPrivacyStory = 0;
static const NSInteger kSCIRowPrivacyMessages = 1;
static const NSInteger kSCIRowPrivacyProfile = 2;
static const NSInteger kSCIPrivacyRowCount = 3;

static const NSInteger kSCIStatusRowCount = 5;

@interface SCITTStatus ()
@property (nonatomic, strong) NSArray<SCITTMediaItem *> *items;
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
    [top presentViewController:host animated:YES completion:nil];
}

/// A small colour-badge icon, drawn the way Settings.app draws its own rows -- the same
/// technique and the same reasoning the X tweak's own settings screen uses it for.
static UIImage *SCITTBadge(NSString *symbolName, UIColor *color) {
    CGSize size = CGSizeMake(29, 29);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                                format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *background =
            [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                        cornerRadius:7];
        [(color ?: [UIColor systemGrayColor]) setFill];
        [background fill];

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:15
                                                             weight:UIImageSymbolWeightMedium];
        UIImage *glyph = [[UIImage systemImageNamed:symbolName withConfiguration:config]
            imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (!glyph) return;

        [glyph drawAtPoint:CGPointMake((size.width - glyph.size.width) / 2,
                                       (size.height - glyph.size.height) / 2)];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"title");
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                          style:UIBarButtonItemStyleDone
                                         target:self
                                         action:@selector(dismissSelf)];

    self.tableView.sectionHeaderTopPadding = 0;

    // Every row here can carry a wrapped, multi-line note under its title. Without an
    // automatic row height every cell is clamped to the table's fixed 44-point default
    // and a two- or three-line note is drawn overlapping the row below it rather than
    // pushing it down -- which is exactly the "text running into itself" a fixed-height
    // subtitle cell produces the moment its detail label wraps past one line.
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pulledToRefresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;

    [self buildHeader];
    [self buildFooter];
    [self reload];
}

- (void)pulledToRefresh {
    [self reload];
    [self.refreshControl endRefreshing];
}

- (void)reload {
    self.items = [SCITTMedia recent];
    [self.tableView reloadData];
}

/// The card at the top: what this tweak is, and whether each of its three moving parts
/// actually attached -- read live so the card can never disagree with the rows below it.
- (void)buildHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectZero];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 18;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [header addSubview:card];

    UIImageView *mark = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"music.note"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:32
                                                                                  weight:UIImageSymbolWeightSemibold]]];
    mark.tintColor = SCIAccent();
    mark.contentMode = UIViewContentModeScaleAspectFit;
    [mark setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *name = [[UILabel alloc] init];
    name.text = SCILocalized(@"title");
    name.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    name.textColor = [UIColor labelColor];

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
    // The cell overlay is the primary surface and needs only one of the two cell
    // classes; the interaction rail is a second, optional surface, not a requirement
    // for this pill to read as attached. AWEFeedViewCell is the one a live device
    // report actually confirmed -- AWEFeedViewTemplateCell is kept alongside it in
    // case some other surface still uses that name.
    BOOL button = NSClassFromString(@"AWEFeedViewCell") != nil
        || NSClassFromString(@"AWEFeedViewTemplateCell") != nil;
    BOOL bypass = NSClassFromString(@"TTAdSplashDeviceHelper") != nil;

    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_ads") on:adsFilter]];
    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_button") on:button]];
    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_bypass") on:bypass]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[top, pills]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
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

- (void)buildFooter {
    UILabel *credit = [[UILabel alloc] init];
    credit.text = SCILocalized(@"credit");
    credit.numberOfLines = 0;
    credit.textAlignment = NSTextAlignmentCenter;
    credit.font = [UIFont systemFontOfSize:12];
    credit.textColor = [UIColor secondaryLabelColor];

    CGFloat width = [UIScreen mainScreen].bounds.size.width - 48;
    CGSize fits = [credit sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, fits.height + 40)];
    credit.frame = CGRectMake(24, 20, width, fits.height);
    [footer addSubview:credit];

    self.tableView.tableFooterView = footer;
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSCISectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kSCISectionControls) return kSCIControlsRowCount;
    if (section == kSCISectionPrivacy) return kSCIPrivacyRowCount;
    if (section == kSCISectionDownload) return self.items.count ?: 1;
    if (section == kSCISectionStatus) return kSCIStatusRowCount;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSCISectionControls) return SCILocalized(@"section_controls");
    if (section == kSCISectionPrivacy) return SCILocalized(@"section_privacy");
    if (section == kSCISectionDownload) return SCILocalized(@"section_download");
    if (section == kSCISectionStatus) return SCILocalized(@"section_status");
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == kSCISectionDownload && self.items.count) return SCILocalized(@"media_footer");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSCISectionControls) {
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [self fillControlCell:cell row:indexPath.row];
        return cell;
    }

    if (indexPath.section == kSCISectionPrivacy) {
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [self fillPrivacyCell:cell row:indexPath.row];
        return cell;
    }

    if (indexPath.section == kSCISectionDownload) {
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        [self fillMediaCell:cell row:indexPath.row];
        return cell;
    }

    // Subtitle, not Value1 -- Value1 lays its two labels side by side on one line by
    // design, and several of these rows carry a long, dynamically-built diagnostic
    // string (a comma list of hooks, a whole superview chain) that has nowhere to wrap
    // to in that layout except on top of the title beside it. Subtitle stacks the note
    // under the title instead, the same shape every other section on this screen uses.
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self fillStatusCell:cell row:indexPath.row];
    return cell;
}

- (void)fillControlCell:(UITableViewCell *)cell row:(NSInteger)row {
    NSString *key = nil, *title = nil, *note = nil, *icon = nil;
    UIColor *color = nil;

    if (row == kSCIRowAds) {
        key = SCIPrefHideAds;
        title = SCILocalized(@"row_ads");
        note = SCILocalized(@"row_ads_note");
        icon = @"nosign";
        color = [UIColor systemRedColor];
    } else if (row == kSCIRowDownloadButton) {
        key = SCIPrefDownloadButton;
        title = SCILocalized(@"row_download_button");
        note = SCILocalized(@"row_download_button_note");
        icon = @"arrow.down.circle.fill";
        color = SCIAccent();
    } else {
        key = SCIPrefBypass;
        title = SCILocalized(@"row_bypass");
        note = SCILocalized(@"row_bypass_note");
        icon = @"shield.lefthalf.filled";
        color = [UIColor systemIndigoColor];
    }

    [self fillSwitchCell:cell key:key title:title note:note icon:icon color:color tag:row
                  action:@selector(controlToggled:)];
}

- (void)controlToggled:(UISwitch *)toggle {
    NSString *key = (toggle.tag == kSCIRowAds) ? SCIPrefHideAds
                   : (toggle.tag == kSCIRowDownloadButton) ? SCIPrefDownloadButton
                   : (toggle.tag == kSCIRowBypass) ? SCIPrefBypass
                   : nil;
    if (!key) return;
    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];
}

- (void)fillPrivacyCell:(UITableViewCell *)cell row:(NSInteger)row {
    NSString *key = nil, *title = nil, *note = nil, *icon = nil;
    UIColor *color = [UIColor systemTealColor];

    if (row == kSCIRowPrivacyStory) {
        key = SCIPrefPrivacyStory;
        title = SCILocalized(@"row_privacy_story");
        note = SCILocalized(@"row_privacy_story_note");
        icon = @"eye.slash.fill";
    } else if (row == kSCIRowPrivacyMessages) {
        key = SCIPrefPrivacyMessages;
        title = SCILocalized(@"row_privacy_messages");
        note = SCILocalized(@"row_privacy_messages_note");
        icon = @"message.fill";
    } else {
        key = SCIPrefPrivacyProfile;
        title = SCILocalized(@"row_privacy_profile");
        note = SCILocalized(@"row_privacy_profile_note");
        icon = @"person.fill.questionmark";
    }

    [self fillSwitchCell:cell key:key title:title note:note icon:icon color:color tag:row
                  action:@selector(privacyToggled:)];
}

- (void)privacyToggled:(UISwitch *)toggle {
    NSString *key = (toggle.tag == kSCIRowPrivacyStory) ? SCIPrefPrivacyStory
                   : (toggle.tag == kSCIRowPrivacyMessages) ? SCIPrefPrivacyMessages
                   : (toggle.tag == kSCIRowPrivacyProfile) ? SCIPrefPrivacyProfile
                   : nil;
    if (!key) return;
    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];
}

/// One row shared by Controls and Privacy: a title, a wrapped note under it, a coloured
/// badge, and a switch bound to `key`. `tag` says which row fired without a side table
/// to keep in step with the switches themselves.
- (void)fillSwitchCell:(UITableViewCell *)cell
                    key:(NSString *)key
                  title:(NSString *)title
                   note:(NSString *)note
                   icon:(NSString *)icon
                  color:(UIColor *)color
                    tag:(NSInteger)tag
                 action:(SEL)action {
    cell.textLabel.text = title;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = note;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = SCITTBadge(icon, color);

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = SCIAccent();
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    toggle.tag = tag;
    [toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
}

- (void)fillMediaCell:(UITableViewCell *)cell row:(NSInteger)row {
    if (!self.items.count) {
        cell.textLabel.text = SCILocalized(@"media_empty");
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return;
    }

    SCITTMediaItem *item = self.items[row];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = NSDateFormatterNoStyle;

    cell.textLabel.text = SCILocalized(@"media_save");
    cell.detailTextLabel.text = [formatter stringFromDate:item.seen];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = SCITTBadge(@"arrow.down.circle.fill", SCIAccent());
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)fillStatusCell:(UITableViewCell *)cell row:(NSInteger)row {
    cell.detailTextLabel.numberOfLines = 0;

    switch (row) {
        case 0:
            cell.textLabel.text = SCILocalized(@"status_gate");
            cell.detailTextLabel.text =
                SCIPanelAllowsThisApp() ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off");
            cell.imageView.image = SCITTBadge(@"switch.2", [UIColor systemGrayColor]);
            break;
        case 1:
            cell.textLabel.text = SCILocalized(@"diag_ads");
            cell.detailTextLabel.text = [SCITTDiagnostics adFilterState];
            cell.imageView.image = SCITTBadge(@"nosign", [UIColor systemRedColor]);
            break;
        case 2:
            cell.textLabel.text = SCILocalized(@"status_button");
            cell.detailTextLabel.text = SCITTButtonReport();
            cell.imageView.image = SCITTBadge(@"arrow.down.circle.fill", SCIAccent());
            break;
        case 3:
            cell.textLabel.text = SCILocalized(@"diag_bypass");
            cell.detailTextLabel.text = [SCITTDiagnostics bypassState];
            cell.imageView.image = SCITTBadge(@"shield.lefthalf.filled", [UIColor systemIndigoColor]);
            break;
        default:
            cell.textLabel.text = SCILocalized(@"diag_privacy");
            cell.detailTextLabel.text = [SCITTDiagnostics privacyState];
            cell.imageView.image = SCITTBadge(@"eye.slash.fill", [UIColor systemTealColor]);
            break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != kSCISectionDownload || !self.items.count) return;

    // Saved on the tap, no confirmation sheet -- nothing destroyed, nothing sent
    // anywhere, the same reasoning the X tweak's own media list uses for this.
    [SCITTDownload save:self.items[indexPath.row]];
}

@end
