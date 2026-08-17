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
/// report dumped underneath. Controls first, then what has been captured, then the
/// numbers behind each feature -- the same shape the X tweak's own settings screen
/// (SCITWSettings.m) already settled on for the same reason: a screen with several
/// unrelated things to say reads better sectioned than run together.
///

static const NSInteger kSCISectionControls = 0;
static const NSInteger kSCISectionDownload = 1;
static const NSInteger kSCISectionStatus = 2;
static const NSInteger kSCISectionCount = 3;

static const NSInteger kSCIRowAds = 0;
static const NSInteger kSCIRowDownloadButton = 1;
static const NSInteger kSCIRowBypass = 2;
static const NSInteger kSCIRowPrivacy = 3;
static const NSInteger kSCIControlsRowCount = 4;

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
    BOOL button = NSClassFromString(@"AWEFeedViewTemplateCell") != nil
        && (NSClassFromString(@"TTKFeedInteractionStackView") != nil
            || NSClassFromString(@"TTKFeedRightInteractionStackView") != nil);
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
    if (section == kSCISectionDownload) return self.items.count ?: 1;
    if (section == kSCISectionStatus) return 4; // gate, ads, button, bypass+privacy folded together
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSCISectionControls) return SCILocalized(@"section_controls");
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

    if (indexPath.section == kSCISectionDownload) {
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        [self fillMediaCell:cell row:indexPath.row];
        return cell;
    }

    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
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
    } else if (row == kSCIRowBypass) {
        key = SCIPrefBypass;
        title = SCILocalized(@"row_bypass");
        note = SCILocalized(@"row_bypass_note");
        icon = @"shield.lefthalf.filled";
        color = [UIColor systemIndigoColor];
    } else {
        key = SCIPrefPrivacy;
        title = SCILocalized(@"row_privacy");
        note = SCILocalized(@"row_privacy_note");
        icon = @"eye.slash.fill";
        color = [UIColor systemTealColor];
    }

    cell.textLabel.text = title;
    cell.detailTextLabel.text = note;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = SCITTBadge(icon, color);

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = SCIAccent();
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    toggle.tag = row;
    [toggle addTarget:self action:@selector(controlToggled:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
}

- (void)controlToggled:(UISwitch *)toggle {
    NSString *key = (toggle.tag == kSCIRowAds) ? SCIPrefHideAds
                   : (toggle.tag == kSCIRowDownloadButton) ? SCIPrefDownloadButton
                   : (toggle.tag == kSCIRowBypass) ? SCIPrefBypass
                   : (toggle.tag == kSCIRowPrivacy) ? SCIPrefPrivacy
                   : nil;
    if (!key) return;
    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];
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
    switch (row) {
        case 0:
            cell.textLabel.text = SCILocalized(@"status_gate");
            cell.detailTextLabel.text =
                SCIPanelAllowsThisApp() ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off");
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = SCITTBadge(@"switch.2", [UIColor systemGrayColor]);
            break;
        case 1:
            cell.textLabel.text = SCILocalized(@"diag_ads");
            cell.detailTextLabel.text = [SCITTDiagnostics adFilterState];
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = SCITTBadge(@"nosign", [UIColor systemRedColor]);
            break;
        case 2:
            cell.textLabel.text = SCILocalized(@"status_button");
            cell.detailTextLabel.text = SCITTButtonReport();
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = SCITTBadge(@"arrow.down.circle.fill", SCIAccent());
            break;
        default: {
            NSString *bypass = [SCITTDiagnostics bypassState];
            NSString *privacy = [SCITTDiagnostics privacyState];
            cell.textLabel.text = [NSString stringWithFormat:@"%@ / %@",
                SCILocalized(@"diag_bypass"), SCILocalized(@"diag_privacy")];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@", bypass, privacy];
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = SCITTBadge(@"shield.lefthalf.filled", [UIColor systemIndigoColor]);
            break;
        }
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
