#import "SCITTStatus.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCITTDiagnostics.h"
#import "../Features/Download/SCITTMedia.h"
#import "../Features/Download/SCITTWatermark.h"
#import "../Features/Interface/SCITTProgressBar.h"
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

/// **The Download list is gone, on request, and its absence is the design.** It was a
/// list of timestamps with a Save button each -- a debugging aid wearing a feature's
/// clothes. Nobody opens a settings screen to pick a video out of thirty unlabelled
/// rows they cannot see; the in-feed button beside share is the whole interface, and a
/// second, worse way to do the same thing only made the screen look unfinished.
/// `SCITTMedia` still keeps its recent list -- the button reads from it -- it just has
/// no UI of its own any more.
static const NSInteger kSCISectionControls = 0;
static const NSInteger kSCISectionPrivacy = 1;
static const NSInteger kSCISectionStatus = 2;
static const NSInteger kSCISectionCount = 3;

static const NSInteger kSCIRowAds = 0;
static const NSInteger kSCIRowDownloadButton = 1;
static const NSInteger kSCIRowPhotoDownload = 2;
static const NSInteger kSCIRowProgressBar = 3;
static const NSInteger kSCIRowExternalHD = 4;
static const NSInteger kSCIRowBypass = 5;
static const NSInteger kSCIControlsRowCount = 6;

static const NSInteger kSCIRowPrivacyStory = 0;
static const NSInteger kSCIRowPrivacyMessages = 1;
static const NSInteger kSCIRowPrivacyProfile = 2;
static const NSInteger kSCIPrivacyRowCount = 3;

static const NSInteger kSCIStatusRowCount = 13;

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

    // The Status section's own rows can each run to a long, dynamically-built string
    // -- every candidate chain's own failure reason, every property name on the live
    // class -- exactly the kind of thing somebody reporting a bug needs to paste
    // whole rather than retype from a screenshot.
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                        target:self
                                                        action:@selector(copyReport)];

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
    BOOL button = NSClassFromString(@"TTKFeedInteractionStackView") != nil
        || NSClassFromString(@"TTKFeedRightInteractionStackView") != nil;
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

/// Everything the Status section shows, as plain text, on the pasteboard -- so a
/// report is one paste instead of several photos of a scrolling screen.
- (void)copyReport {
    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"Albrhi for TikTok %@\n", SCIVersionString];
    [report appendFormat:@"app %@\n\n",
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];

    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_gate"),
        SCIPanelAllowsThisApp() ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off")];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"diag_ads"), [SCITTDiagnostics adFilterState]];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_button"), SCITTButtonReport()];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_media_resolve"), [SCITTMedia lastAttemptState]];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_download"), SCITTDownloadReport()];

    // The copyable report is built here and the table is built below, from two separate
    // lists -- so a row added to one is silently missing from the other. That is exactly what
    // happened to the gear ladder: it was added to the table, asked for by name, and the
    // report that came back had never contained it. Anything added to one belongs in both.
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_gears"), [SCITTMedia gearLadder]];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_measured"), SCITTMeasuredReport()];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_watermark"), SCITTWatermarkReport()];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_progress_bar"), SCITTProgressBarReport()];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_cell_accessors"),
        // AWEFeedViewTemplateCell -- the class the feed actually uses.
        //
        // This asked AWEFeedViewCell, which is why the list came back full of accessibility
        // and layout internals and nothing resembling a model: it was dumping a different
        // class from the one the button is on. Three reports printed that list and nobody
        // noticed it was the wrong object.
        // Unfiltered on purpose.
        //
        // The filter was model/aweme/item/data, and what came back was every UIKit and
        // accessibility category that happens to contain "item" or "data" -- focusItem,
        // pageItem, dataOwner -- and nothing whatever about a video. Which is itself the
        // finding: **this cell has no aweme accessor of its own.** So the model is reached
        // some other way, and a filter built from names I expected is the last thing that
        // will show me the one I did not.
        [SCITTMedia accessorsOnClassNamed:@"AWEFeedViewTemplateCell" matching:@[]]];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_media_candidates"),
        [SCITTMedia candidateAccessorsOnAwemeModel]];

    // AWEVideoModel's own accessors -- the one list that has never been in this report, and
    // the reason the audio problem is still open.
    //
    // The report says resolution succeeds "via AWEVideoModel.playURL.originURLList" and then
    // that the saved file is 972317 bytes of audio/mp4. Both are true, which means the link
    // that resolves is not the video -- and every accessor listed above belongs to the
    // *aweme* model, not to the video model the link actually comes from. So the list that
    // would name the right one has never been printed.
    //
    // TikTok 46.4.0's framework does contain downloadAddr, playAddr, playAddrH264,
    // bitrateModels, HDRBitrateModels and SDRBitrateModels; what it does not say is which of
    // them are on AWEVideoModel, because a selector dump is global. Trying downloadAddr first
    // was the obvious guess and it did not win, so this asks the device instead of guessing a
    // second time.
    [report appendFormat:@"%@: %@\n", SCILocalized(@"status_video_accessors"),
        [SCITTMedia accessorsOnClassNamed:@"AWEVideoModel"
                                  matching:@[@"url", @"URL", @"addr", @"Addr", @"bitrate",
                                             @"bitRate", @"uri", @"URI", @"play", @"download"]]];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"diag_bypass"), [SCITTDiagnostics bypassState]];
    [report appendFormat:@"%@: %@\n", SCILocalized(@"diag_privacy"), [SCITTDiagnostics privacyState]];

    [UIPasteboard generalPasteboard].string = report;

    UIImpactFeedbackGenerator *haptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                             message:SCILocalized(@"report_copied")
                                      preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSCISectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kSCISectionControls) return kSCIControlsRowCount;
    if (section == kSCISectionPrivacy) return kSCIPrivacyRowCount;
    if (section == kSCISectionStatus) return kSCIStatusRowCount;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSCISectionControls) return SCILocalized(@"section_controls");
    if (section == kSCISectionPrivacy) return SCILocalized(@"section_privacy");
    if (section == kSCISectionStatus) return SCILocalized(@"section_status");
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
    } else if (row == kSCIRowPhotoDownload) {
        key = SCIPrefPhotoDownload;
        title = SCILocalized(@"row_photo_download");
        note = SCILocalized(@"row_photo_download_note");
        icon = @"photo.on.rectangle.angled";
        color = [UIColor systemPinkColor];
    } else if (row == kSCIRowProgressBar) {
        key = SCIPrefProgressBar;
        title = SCILocalized(@"row_progress_bar");
        note = SCILocalized(@"row_progress_bar_note");
        icon = @"slider.horizontal.below.rectangle";
        color = [UIColor systemBlueColor];
    } else if (row == kSCIRowExternalHD) {
        key = SCIPrefExternalHD;
        title = SCILocalized(@"row_external_hd");
        note = SCILocalized(@"row_external_hd_note");
        icon = @"antenna.radiowaves.left.and.right";
        color = [UIColor systemOrangeColor];
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
                   : (toggle.tag == kSCIRowPhotoDownload) ? SCIPrefPhotoDownload
                   : (toggle.tag == kSCIRowProgressBar) ? SCIPrefProgressBar
                   : (toggle.tag == kSCIRowExternalHD) ? SCIPrefExternalHD
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
            // What the resolution chain itself last did -- separate from whether a
            // button ever got placed, because "0 placed" has two different causes
            // (the hook never fires, or it fires and finds nothing to resolve) that
            // need two different fixes, and this is the line that tells them apart.
            cell.textLabel.text = SCILocalized(@"status_media_resolve");
            cell.detailTextLabel.text = [SCITTMedia lastAttemptState];
            cell.imageView.image = SCITTBadge(@"link", [UIColor systemPurpleColor]);
            break;
        case 4:
            cell.textLabel.text = SCILocalized(@"status_download");
            cell.detailTextLabel.text = SCITTDownloadReport();
            cell.imageView.image = SCITTBadge(@"square.and.arrow.down", SCIAccent());
            break;
        case 5:
            // The cell's own model accessor, which is what the button needs to stop
            // saving whichever URL was resolved most recently and start saving the
            // video it is actually attached to.
            cell.textLabel.text = SCILocalized(@"status_cell_accessors");
            cell.detailTextLabel.text =
                [SCITTMedia accessorsOnClassNamed:@"AWEFeedViewTemplateCell" matching:@[]];
            cell.imageView.image = SCITTBadge(@"rectangle.on.rectangle", [UIColor systemPurpleColor]);
            break;
        case 6:
            cell.textLabel.text = SCILocalized(@"status_media_candidates");
            cell.detailTextLabel.text = [SCITTMedia candidateAccessorsOnAwemeModel];
            cell.imageView.image = SCITTBadge(@"magnifyingglass", [UIColor systemPurpleColor]);
            break;
        case 7:
            // Three states, not two: the class may be absent from this build, present and
            // switched off, or working -- and only the first is a reason to change any code.
            cell.textLabel.text = SCILocalized(@"status_progress_bar");
            cell.detailTextLabel.text = SCITTProgressBarReport();
            cell.imageView.image = SCITTBadge(@"slider.horizontal.below.rectangle",
                                              [UIColor systemBlueColor]);
            break;
        case 8:
            // The ladder, not just the pick. "720 is not HD" and "720 was all there was"
            // look identical from the saved file, and only one of them is a bug here.
            cell.textLabel.text = SCILocalized(@"status_gears");
            cell.detailTextLabel.text = [SCITTMedia gearLadder];
            cell.imageView.image = SCITTBadge(@"square.stack.3d.up", [UIColor systemOrangeColor]);
            break;
        case 9:
            // What the links actually measured. Every other quality line here is a claim
            // about a name -- which chain, which gear -- and this one is a byte count.
            cell.textLabel.text = SCILocalized(@"status_measured");
            cell.detailTextLabel.text = SCITTMeasuredReport();
            cell.imageView.image = SCITTBadge(@"ruler", [UIColor systemGreenColor]);
            break;
        case 10:
            cell.textLabel.text = SCILocalized(@"status_watermark");
            cell.detailTextLabel.text = SCITTWatermarkReport();
            cell.imageView.image = SCITTBadge(@"drop.fill", [UIColor systemCyanColor]);
            break;
        case 11:
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

@end
