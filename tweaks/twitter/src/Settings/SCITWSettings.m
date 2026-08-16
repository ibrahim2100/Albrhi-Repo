#import "SCITWSettings.h"
#import "Tweak.h"          // SCIVersionString, for the card
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Features/Switches/SCITWFeatures.h"
#import "Features/Media/SCITWMedia.h"
#import "Features/Media/SCITWDownload.h"
#import "Diagnostics/SCITWReport.h"

// Media first, under the status. It is what people open this screen for, and a list of
// three hundred switch names above it would bury the one section that does something in
// one tap.
/// Controls first, then what was saved, then information.
///
/// **The tweak's own three settings had no row anywhere on this page.** `Prefs.h` describes
/// the save button as something you can turn off, and the switch layer as the thing to turn
/// off on a build of X where hooking it causes trouble -- and neither had a switch, on the
/// only screen this tweak has. Verbose logging the same. Three preferences, defaults only,
/// no way to reach any of them.
///
/// So Albrhi is section zero and Status has moved down. Status is four rows of information
/// -- what attached, how many keys were seen -- and opening a settings screen with a report
/// puts the reading matter above everything anybody came to change.
///
/// **Media sits right under the quick controls, ahead of Features.** Saving a video or a
/// photo is the reason this tweak's name comes up at all -- it is the first thing asked for
/// when this project took on X -- and a screen that made that scroll past seventeen switch
/// names first would be arranging itself around what is easy to list, not around what
/// somebody opened it to do.
static const NSInteger SCITWSectionAlbrhi   = 0;
static const NSInteger SCITWSectionMedia    = 1;
static const NSInteger SCITWSectionFeatures = 2;
static const NSInteger SCITWSectionStatus   = 3;
static const NSInteger SCITWSectionKeys     = 4;

/// The rows in section zero, in order.
static const NSInteger SCITWAlbrhiSaveButton = 0;
static const NSInteger SCITWAlbrhiSwitchLayer = 1;
static const NSInteger SCITWAlbrhiLogging = 2;
static const NSInteger SCITWAlbrhiRowCount = 3;

@interface SCITWSettings () <UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<SCITWSwitchRecord *> *all;
@property (nonatomic, strong) NSArray<SCITWSwitchRecord *> *shown;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, assign) BOOL changedOnly;
@property (nonatomic, strong) NSArray<SCITWMediaItem *> *media;
@end


/// A small colour-badge icon, drawn the way Settings.app draws its own rows: a rounded
/// square in a colour with a white glyph centred in it.
///
/// `UITableViewCell.imageView` is a plain `UIImageView` with no way to give it a background
/// layer of its own, so the background is baked into the image itself -- the badge is one
/// flat bitmap, not a glyph over a separately-drawn square. That is the whole trick behind
/// every icon in iOS's own Settings app, and it needs no custom cell class here: setting
/// `cell.imageView.image` is enough, and the built-in cell styles already size and place it.
///
/// Returns nothing to draw -- an empty, transparent 29-point square -- when the symbol name
/// does not exist on this iOS version, rather than crashing on a nil image or silently
/// drawing a coloured square with nothing in it that looks like a rendering bug.
///
/// **Deliberately not used on the raw switch list.** Three hundred and more rows redrawing
/// a bitmap each would be spending real work on a list built to be lean and searchable, for
/// a section where every row is already told apart by its own name -- the curated sections
/// below are few enough, and different enough from each other, that an icon is worth its
/// keep on them and would be noise repeated three hundred times on that one.
static UIImage *SCITWBadge(NSString *symbolName, UIColor *color) {
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


@implementation SCITWSettings

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
        // Already ours. Opening a second one would stack two identical screens, and the
        // one underneath keeps its own stale copy of the list.
        if ([top.presentedViewController isKindOfClass:[UINavigationController class]] &&
            [[(UINavigationController *)top.presentedViewController topViewController]
                isKindOfClass:[SCITWSettings class]]) {
            return;
        }
        top = top.presentedViewController;
    }
    if (!top) return;

    SCITWSettings *settings = [[SCITWSettings alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *host =
        [[UINavigationController alloc] initWithRootViewController:settings];

    [top presentViewController:host animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"title");
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"done")
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(dismissSelf)];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                      target:self
                                                      action:@selector(showMenu:)];

    // Search belongs to the navigation bar, not to the table.
    //
    // It was a UISearchBar stacked above a segmented control in a 96-point table header,
    // which scrolled away with the content and took the only way of finding a key with it.
    // A UISearchController pins it under the title, keeps it reachable at any scroll
    // position, and is the control iOS uses for exactly this.
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.placeholder = SCILocalized(@"search_placeholder");
    search.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    // The All/Changed filter, kept -- as the search bar's own scopes rather than a second
    // control stacked above it. Same two choices, one control, and it appears with the
    // keyboard instead of occupying the screen when nobody is searching.
    search.searchBar.scopeButtonTitles = @[SCILocalized(@"filter_all"), SCILocalized(@"filter_changed")];
    search.searchBar.showsScopeBar = NO;
    search.searchBar.delegate = self;
    self.navigationItem.searchController = search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.searchController = search;

    if (@available(iOS 15.0, *)) {
        self.navigationItem.scrollEdgeAppearance = [[UINavigationBarAppearance alloc] init];
        [self.navigationItem.scrollEdgeAppearance configureWithDefaultBackground];
    }

    self.tableView.sectionHeaderTopPadding = 0;

    // A pull re-reads what X has answered since the screen opened, the same as -reload
    // does on any other trigger. Nothing here is fetched over a network -- it is already on
    // the phone -- so the spinner is brief and honest rather than theatre over a delay.
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

/// The card at the top: what this tweak is, and whether it is working.
///
/// What was here was a search field and a filter stacked in a plain 96-point view — two
/// controls and no answer to the first question anyone opening this screen has, which is
/// whether the thing is attached at all. Search moved to the navigation bar where it
/// belongs; this space now says something.
///
/// Built from stack views inside one rounded container. No constraint between siblings that
/// the stack does not own, which is the arrangement that has taken this project's settings
/// screens down twice.
- (void)buildHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 18;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [header addSubview:card];

    // The mark: X's own blue, filled, at a size that reads as an app icon rather than a
    // glyph in a row.
    UIImageView *mark = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:34
                                                                                  weight:UIImageSymbolWeightSemibold]]];
    mark.tintColor = [UIColor systemBlueColor];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    [mark setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *name = [[UILabel alloc] init];
    name.text = SCILocalized(@"title");
    name.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    name.textColor = [UIColor labelColor];

    UILabel *version = [[UILabel alloc] init];
    version.text = [NSString stringWithFormat:@"%@ · X %@", SCIVersionString,
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

    // Three pills, each answering one question the report answers in prose. Green or red,
    // because "attached" and "not attached" is the only distinction that matters here and a
    // colour says it before the words are read.
    UIStackView *pills = [[UIStackView alloc] init];
    pills.axis = UILayoutConstraintAxisHorizontal;
    pills.spacing = 8;
    pills.distribution = UIStackViewDistributionFillEqually;

    // Read from what this screen already loaded, so the card can never disagree with the
    // list below it -- the failure mode of every status display that keeps its own copy.
    BOOL providers = [SCITWSwitches attachedProviders].count > 0;
    BOOL seen = self.all.count > 0;
    BOOL media = self.media.count > 0;

    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_switches") on:providers]];
    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_seen") on:seen]];
    [pills addArrangedSubview:[self pillWithTitle:SCILocalized(@"pill_media") on:media]];

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

    // Measured once and set as the frame, the same reason the footer does it: a table
    // header is laid out before the table has its final width, and a self-sizing one wraps
    // to nothing on the first pass and never recovers.
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    header.frame = CGRectMake(0, 0, width,
        [header systemLayoutSizeFittingSize:CGSizeMake(width, 0)
              withHorizontalFittingPriority:UILayoutPriorityRequired
                    verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height);

    self.tableView.tableHeaderView = header;
}

/// One status pill. Green when the answer is yes, red when it is no, and never grey --
/// "unknown" is not one of the states this screen can honestly report.
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

    // Sized against the screen rather than the table: a table footer is laid out before
    // the table has its final width on the first pass, and asking the table produces a
    // label wrapped to zero columns that then never re-wraps.
    CGFloat width = [UIScreen mainScreen].bounds.size.width - 48;
    CGSize fits = [credit sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];

    UIView *footer = [[UIView alloc] initWithFrame:
        CGRectMake(0, 0, width, fits.height + 40)];
    credit.frame = CGRectMake(24, 20, width, fits.height);
    [footer addSubview:credit];

    self.tableView.tableFooterView = footer;
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.query = searchController.searchBar.text;
    [self reload];
}

/// The All/Changed choice, now the search bar's own scopes.
///
/// The same two options the segmented control offered, on the control iOS provides for
/// exactly this — so the filter appears with the keyboard instead of taking a row of the
/// screen from everyone who is not searching.
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)scope {
    self.changedOnly = (scope == 1);
    [self reload];
}

- (void)reload {
    self.media = [SCITWMedia recent];
    self.all = [SCITWSwitches records];

    NSDictionary<NSString *, NSNumber *> *overrides = [SCITWSwitches allOverrides];
    NSString *needle = [self.query stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]].lowercaseString;

    NSMutableArray<SCITWSwitchRecord *> *shown = [NSMutableArray array];
    for (SCITWSwitchRecord *record in self.all) {
        if (self.changedOnly && !overrides[record.key]) continue;
        if (needle.length && [record.key rangeOfString:needle].location == NSNotFound) continue;
        [shown addObject:record];
    }

    self.shown = shown;
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SCITWSectionAlbrhi) return SCITWAlbrhiRowCount;
    if (section == SCITWSectionStatus) return 4;
    if (section == SCITWSectionMedia) return self.media.count ?: 1;
    if (section == SCITWSectionFeatures) return [SCITWFeatures all].count;
    return self.shown.count ?: 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == SCITWSectionAlbrhi) return SCILocalized(@"section_albrhi");
    if (section == SCITWSectionStatus) return SCILocalized(@"section_status");
    if (section == SCITWSectionMedia) return SCILocalized(@"section_media");
    if (section == SCITWSectionFeatures) return SCILocalized(@"section_features");
    return SCILocalized(@"section_keys");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == SCITWSectionAlbrhi) return SCILocalized(@"albrhi_footer");
    if (section == SCITWSectionMedia) return SCILocalized(@"media_footer");
    if (section == SCITWSectionFeatures) return SCILocalized(@"features_footer");
    if (section == SCITWSectionKeys) return SCILocalized(@"keys_footer");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                               reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == SCITWSectionStatus) {
        [self fillStatusCell:cell row:indexPath.row];
        return cell;
    }

    if (indexPath.section == SCITWSectionMedia) {
        UITableViewCell *row =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:nil];
        [self fillMediaCell:row row:indexPath.row];
        return row;
    }

    if (indexPath.section == SCITWSectionAlbrhi) {
        UITableViewCell *row =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:nil];
        [self fillAlbrhiCell:row row:indexPath.row];
        return row;
    }

    if (indexPath.section == SCITWSectionFeatures) {
        // Its own cell, because a feature row is a title over an explanation and Value1
        // puts the two side by side -- which truncates the explanation to nothing on a
        // phone, and the explanation is the part that says what the switch costs.
        UITableViewCell *row =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:nil];
        [self fillFeatureCell:row row:indexPath.row];
        return row;
    }

    if (!self.shown.count) {
        cell.textLabel.text = SCILocalized(@"keys_empty");
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.text = nil;
        return cell;
    }

    SCITWSwitchRecord *record = self.shown[indexPath.row];
    SCITWOverride override = [SCITWSwitches overrideForKey:record.key];

    // Monospaced, because these are identifiers rather than prose and the underscores are
    // load-bearing -- two keys differing by one word are told apart by their shape here.
    cell.textLabel.text = record.key;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12
                                                       weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines = 0;

    SCITWFeature *owner = override == SCITWOverrideNone
        ? [SCITWFeatures featureOwningKey:record.key] : nil;

    NSString *state;
    if (override != SCITWOverrideNone) {
        state = SCILocalized(override == SCITWOverrideOn ? @"detail_you_on" : @"detail_you_off");
    } else if (owner) {
        // Named, not just marked. "Something is overriding this" is the answer that sends
        // somebody hunting through seventeen switches; naming the feature is one tap.
        NSNumber *wanted = owner.keys[record.key];
        state = [NSString stringWithFormat:SCILocalized(
            wanted.boolValue ? @"detail_feature_on" : @"detail_feature_off"),
            SCILocalized(owner.titleKey)];
    } else {
        state = SCILocalized(record.appAnswer ? @"detail_app_on" : @"detail_app_off");
    }

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", state,
        [NSString stringWithFormat:SCILocalized(@"detail_asked"),
            (unsigned long)record.asked]];
    cell.detailTextLabel.textColor = (override != SCITWOverrideNone)
        ? [UIColor systemBlueColor]
        : (owner ? [UIColor systemTealColor] : [UIColor secondaryLabelColor]);

    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)fillMediaCell:(UITableViewCell *)cell row:(NSInteger)row {
    if (!self.media.count) {
        cell.textLabel.text = SCILocalized(@"media_empty");
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return;
    }

    SCITWMediaItem *item = self.media[row];

    NSString *kind = SCILocalized(item.kind == SCITWMediaKindVideo ? @"media_video"
                                : item.kind == SCITWMediaKindGif   ? @"media_gif"
                                                                   : @"media_image");

    // The alt text where the poster wrote one, and the kind where they did not. "Video"
    // eleven times down a list is a list nobody can pick from, and alt text is the only
    // caption X hands us for a piece of media.
    cell.textLabel.text = item.note.length ? item.note : kind;
    cell.textLabel.numberOfLines = 2;

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:kind];
    if (item.duration > 0.5) {
        [parts addObject:[NSString stringWithFormat:@"%d:%02d",
            (int)(item.duration / 60), (int)item.duration % 60]];
    }
    cell.detailTextLabel.text = [parts componentsJoinedByString:@" · "];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    cell.accessoryType = UITableViewCellAccessoryDetailButton;

    NSString *icon = item.kind == SCITWMediaKindImage ? @"photo.fill" : @"play.rectangle.fill";
    UIColor *color = item.kind == SCITWMediaKindImage ? [UIColor systemBlueColor]
                                                       : [UIColor systemPurpleColor];
    cell.imageView.image = SCITWBadge(icon, color);
}

/// The tweak's own three settings, which had no row until now.
///
/// Read and written straight through NSUserDefaults, the way every hook in this tweak reads
/// them. No indirection worth adding for three booleans, and using the same call the hooks
/// use means a switch here and a hook there can never disagree about where the value lives.
- (void)fillAlbrhiCell:(UITableViewCell *)cell row:(NSInteger)row {
    NSString *key = nil;
    NSString *title = nil;
    NSString *note = nil;
    NSString *icon = nil;
    UIColor *color = nil;
    BOOL defaultOn = YES;

    if (row == SCITWAlbrhiSaveButton) {
        key = SCIPrefInlineButton;
        title = SCILocalized(@"albrhi_save_button");
        note = SCILocalized(@"albrhi_save_button_note");
        icon = @"arrow.down.circle.fill";
        color = [UIColor systemBlueColor];
    } else if (row == SCITWAlbrhiSwitchLayer) {
        key = SCIPrefSwitchLayer;
        title = SCILocalized(@"albrhi_switch_layer");
        note = SCILocalized(@"albrhi_switch_layer_note");
        icon = @"switch.2";
        color = [UIColor systemOrangeColor];
    } else {
        key = SCIPrefVerboseLogging;
        title = SCILocalized(@"albrhi_logging");
        note = SCILocalized(@"albrhi_logging_note");
        icon = @"doc.text.magnifyingglass";
        color = [UIColor systemGrayColor];
        defaultOn = NO;
    }

    cell.textLabel.text = title;
    cell.detailTextLabel.text = note;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.imageView.image = SCITWBadge(icon, color);

    // Turning the switch layer off makes this tweak do nothing at all, which is a bigger
    // step than any single feature and is marked the way the cautious features are.
    if (row == SCITWAlbrhiSwitchLayer) cell.textLabel.textColor = [UIColor systemOrangeColor];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = ([defaults objectForKey:key] == nil) ? defaultOn : [defaults boolForKey:key];
    toggle.tag = row;
    [toggle addTarget:self
               action:@selector(albrhiToggled:)
     forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
}

- (void)albrhiToggled:(UISwitch *)toggle {
    // All three named, rather than two named and the third left as the default. A default
    // that happens to be right is a default that writes the wrong key the moment a fourth
    // row is added above it -- and check.py failed the build for the unused constant, which
    // is the same fact from the other end.
    NSString *key = nil;
    if (toggle.tag == SCITWAlbrhiSaveButton) key = SCIPrefInlineButton;
    if (toggle.tag == SCITWAlbrhiSwitchLayer) key = SCIPrefSwitchLayer;
    if (toggle.tag == SCITWAlbrhiLogging) key = SCIPrefVerboseLogging;
    if (!key) return;

    [[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];

    // The switch layer is hooked from the constructor, so moving it changes nothing until X
    // is opened again -- and a switch that appears to do nothing is the complaint this
    // project has answered most often. Said here rather than discovered.
    if (toggle.tag == SCITWAlbrhiSwitchLayer) [self say:SCILocalized(@"restart_note")];
}

- (void)fillFeatureCell:(UITableViewCell *)cell row:(NSInteger)row {
    SCITWFeature *feature = [SCITWFeatures all][row];

    cell.textLabel.text = SCILocalized(feature.titleKey);
    cell.detailTextLabel.text = SCILocalized(feature.noteKey);
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.imageView.image = SCITWBadge(feature.iconName, feature.iconColor);

    // Marked, not hidden. Each of these removes a disclosure, changes what X is told about
    // the device, or turns on something X shipped switched off -- and a row that looks
    // exactly like "hide ads" is a row nobody reads before flipping.
    if (feature.cautious) cell.textLabel.textColor = [UIColor systemOrangeColor];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = [SCITWFeatures isOn:feature];
    toggle.tag = row;
    [toggle addTarget:self
               action:@selector(featureToggled:)
     forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
}

- (void)featureToggled:(UISwitch *)toggle {
    NSArray<SCITWFeature *> *features = [SCITWFeatures all];
    if (toggle.tag < 0 || (NSUInteger)toggle.tag >= features.count) return;

    [SCITWFeatures setOn:toggle.isOn feature:features[toggle.tag]];

    // The keys section below shows which feature owns each row, so it is now stale. The
    // features section is not reloaded: doing that mid-animation snaps the switch the user
    // is still touching back to where it started and reads as the toggle not working.
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SCITWSectionKeys]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)fillStatusCell:(UITableViewCell *)cell row:(NSInteger)row {
    switch (row) {
        case 0: {
            cell.textLabel.text = SCILocalized(@"status_gate");
            cell.detailTextLabel.text = SCIPanelAllowsThisApp()
                ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off");
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = SCITWBadge(@"shield.lefthalf.filled", [UIColor systemBlueColor]);
            break;
        }
        case 1: {
            NSArray<NSString *> *providers = [SCITWSwitches attachedProviders];
            cell.textLabel.text = SCILocalized(@"status_providers");
            cell.detailTextLabel.text = providers.count
                ? [NSString stringWithFormat:@"%lu", (unsigned long)providers.count]
                : SCILocalized(@"status_providers_none");
            cell.imageView.image = SCITWBadge(@"link", [UIColor systemIndigoColor]);
            break;
        }
        case 2: {
            cell.textLabel.text = SCILocalized(@"status_keys");
            cell.detailTextLabel.text =
                [NSString stringWithFormat:@"%lu", (unsigned long)self.all.count];
            cell.imageView.image = SCITWBadge(@"key.fill", [UIColor systemTealColor]);
            break;
        }
        default: {
            cell.textLabel.text = SCILocalized(@"status_asked");
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",
                (unsigned long)[SCITWSwitches totalAsked]];
            cell.imageView.image = SCITWBadge(@"questionmark.circle.fill", [UIColor systemGrayColor]);
            break;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == SCITWSectionMedia) {
        if (!self.media.count) return;

        // Saved on the tap, with no confirmation. Nothing is destroyed and nothing is sent
        // anywhere -- a sheet asking "are you sure you want to keep this" is a step that
        // protects against nothing, and this project puts confirmations only where a
        // mis-tap becomes a notification somebody else sees.
        [SCITWDownload save:self.media[indexPath.row]];
        return;
    }

    if (indexPath.section != SCITWSectionKeys || !self.shown.count) return;

    SCITWSwitchRecord *record = self.shown[indexPath.row];
    [self askAbout:record fromCell:[tableView cellForRowAtIndexPath:indexPath]];
}

- (void)askAbout:(SCITWSwitchRecord *)record fromCell:(UITableViewCell *)cell {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:record.key
                                            message:SCILocalized(@"restart_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    void (^choose)(NSString *, SCITWOverride) = ^(NSString *key, SCITWOverride value) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(key)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
            [SCITWSwitches setOverride:value forKey:record.key];
            [self reload];
        }]];
    };

    choose(@"choose_default", SCITWOverrideNone);
    choose(@"choose_on", SCITWOverrideOn);
    choose(@"choose_off", SCITWOverrideOff);

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    // Required on iPad, where an action sheet with nothing to point at is not shown at
    // all rather than being shown badly.
    sheet.popoverPresentationController.sourceView = cell ?: self.view;
    sheet.popoverPresentationController.sourceRect = (cell ?: self.view).bounds;

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showMenu:(UIBarButtonItem *)sender {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"menu_report")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        NSString *name = SCITWWriteReport();
        NSString *message = name
            ? [NSString stringWithFormat:SCILocalized(@"report_saved"), name]
            : SCILocalized(@"report_failed");
        [self say:message];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"menu_forget_media")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        [SCITWMedia forgetAll];
        [self reload];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"menu_reset")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *action) {
        [self confirmReset];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    sheet.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)confirmReset {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"menu_reset")
                                            message:SCILocalized(@"menu_reset_body")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"menu_reset")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *action) {
        [SCITWSwitches clearOverrides];

        // The features as well. The button says "undo all my answers", and leaving
        // seventeen switches on while emptying the map they feed would leave the app
        // changed and the screen claiming it was not.
        for (SCITWFeature *feature in [SCITWFeatures all]) {
            [SCITWFeatures setOn:NO feature:feature];
        }

        [self.tableView reloadData];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)say:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"title")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
