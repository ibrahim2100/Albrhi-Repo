#import "SCITWSettings.h"
#import "SCITWTable.h"
#import "SCITWPageController.h"
#import "Model/SCITWPageRegistry.h"
#import "SCITWKeysList.h"
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

    // No search bar on this screen any more -- it belonged to the raw key list, and the
    // list moved to its own page (SCITWKeysList), search and all. This screen keeps only
    // the count of what it holds.
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

    // Asked of the same sources the rows are built from, rather than of a copy this screen
    // keeps -- a status display holding its own snapshot is how a card and the list under it
    // come to disagree.
    BOOL providers = [SCITWSwitches attachedProviders].count > 0;
    BOOL seen = [SCITWSwitches records].count > 0;
    BOOL media = [SCITWMedia recent].count > 0;

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

#pragma mark - The list

/// The first screen: the switch layer, then one row per page.
///
/// **It used to be every section this tweak has, one under another.** Nine sections and
/// something over thirty rows, so finding the link cleaner meant scrolling past the save
/// button, the timeline filters, the feature list and the diagnostics. Each of those is its
/// own file already; this makes each of them its own screen too, which is the shape the
/// YouTube tweak settled on when its own screen outgrew one table.
- (NSArray<SCITWSection *> *)buildSections {
    NSMutableArray<SCITWSection *> *sections = [NSMutableArray array];

    // The switch layer, above everything, drawn as the heading it is: turning it off does
    // not disable the feature page, it removes it from the list below.
    SCITWRow *layer = [SCITWRow switchRow:SCILocalized(@"albrhi_switch_layer")
                                     note:SCILocalized(@"layer_row_note")
                                   symbol:@"switch.2"
                                     tint:[UIColor systemPurpleColor]
                                  prefKey:SCIPrefSwitchLayer];
    layer.prominent = YES;
    layer.onChange = ^(__unused BOOL on) { };
    [sections addObject:[SCITWSection titled:nil
                                      footer:SCILocalized(@"albrhi_switch_layer_note")
                                        rows:@[layer]]];

    NSMutableArray<SCITWRow *> *pageRows = [NSMutableArray array];
    for (SCITWPage *page in [SCITWPageRegistry pages]) {
        // A page with nothing in it is not listed. That is how the feature page disappears
        // with the switch layer, and how a page for a class this build does not carry never
        // offers a screen that opens onto nothing.
        if (![SCITWPageRegistry sectionsForPage:page host:self].count) continue;

        __weak __typeof(self) weakSelf = self;
        [pageRows addObject:[SCITWRow actionRow:page.title
                                           note:page.note
                                         symbol:page.symbol
                                           tint:page.tint
                                         action:^{
            __typeof(self) strongSelf = weakSelf;
            if (!strongSelf.navigationController) return;

            SCITWPageController *controller = [[SCITWPageController alloc] initWithPage:page];
            [strongSelf.navigationController pushViewController:controller animated:YES];
        }]];
    }

    if (pageRows.count) {
        [sections addObject:[SCITWSection titled:nil footer:nil rows:pageRows]];
    }

    return sections;
}

/// Rebuilt on the way back, because a page can change which pages exist -- switching the
/// layer off inside Advanced would otherwise leave its row in a list that no longer has it.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
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
