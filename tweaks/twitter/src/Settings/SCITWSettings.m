#import "SCITWSettings.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Diagnostics/SCITWReport.h"

static const NSInteger SCITWSectionStatus = 0;
static const NSInteger SCITWSectionKeys   = 1;

@interface SCITWSettings () <UISearchBarDelegate>
@property (nonatomic, strong) NSArray<SCITWSwitchRecord *> *all;
@property (nonatomic, strong) NSArray<SCITWSwitchRecord *> *shown;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, assign) BOOL changedOnly;
@property (nonatomic, strong) UISearchBar *searchBar;
@end


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

    [self buildHeader];
    [self buildFooter];
    [self reload];
}

/// The search field and the All/Changed filter, in one header.
///
/// A search field rather than a scroll: X asks about hundreds of keys and the list is
/// ordered by how often each was asked, so anything specific is nowhere near the top by
/// design. Without a way to type a name this screen would be a wall.
- (void)buildHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 96)];

    UISegmentedControl *filter = [[UISegmentedControl alloc] initWithItems:@[
        SCILocalized(@"filter_all"),
        SCILocalized(@"filter_changed"),
    ]];
    filter.selectedSegmentIndex = 0;
    filter.translatesAutoresizingMaskIntoConstraints = NO;
    [filter addTarget:self
               action:@selector(filterChanged:)
     forControlEvents:UIControlEventValueChanged];
    [header addSubview:filter];

    UISearchBar *search = [[UISearchBar alloc] init];
    search.delegate = self;
    search.placeholder = SCILocalized(@"search_placeholder");
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    search.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:search];
    self.searchBar = search;

    [NSLayoutConstraint activateConstraints:@[
        [filter.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
        [filter.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [filter.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],

        [search.topAnchor constraintEqualToAnchor:filter.bottomAnchor constant:6],
        [search.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:8],
        [search.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-8],
    ]];

    self.tableView.tableHeaderView = header;
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

- (void)filterChanged:(UISegmentedControl *)control {
    self.changedOnly = (control.selectedSegmentIndex == 1);
    [self reload];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
    self.query = text;
    [self reload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)reload {
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
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SCITWSectionStatus) return 4;
    return self.shown.count ?: 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return SCILocalized(section == SCITWSectionStatus ? @"section_status" : @"section_keys");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == SCITWSectionKeys ? SCILocalized(@"keys_footer") : nil;
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

    NSString *state = override == SCITWOverrideNone
        ? SCILocalized(record.appAnswer ? @"detail_app_on" : @"detail_app_off")
        : SCILocalized(override == SCITWOverrideOn ? @"detail_you_on" : @"detail_you_off");

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", state,
        [NSString stringWithFormat:SCILocalized(@"detail_asked"),
            (unsigned long)record.asked]];
    cell.detailTextLabel.textColor = override == SCITWOverrideNone
        ? [UIColor secondaryLabelColor] : [UIColor systemBlueColor];

    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)fillStatusCell:(UITableViewCell *)cell row:(NSInteger)row {
    switch (row) {
        case 0: {
            cell.textLabel.text = SCILocalized(@"status_gate");
            cell.detailTextLabel.text = SCIPanelAllowsThisApp()
                ? SCILocalized(@"gate_on") : SCILocalized(@"gate_off");
            cell.detailTextLabel.numberOfLines = 0;
            break;
        }
        case 1: {
            NSArray<NSString *> *providers = [SCITWSwitches attachedProviders];
            cell.textLabel.text = SCILocalized(@"status_providers");
            cell.detailTextLabel.text = providers.count
                ? [NSString stringWithFormat:@"%lu", (unsigned long)providers.count]
                : SCILocalized(@"status_providers_none");
            break;
        }
        case 2: {
            cell.textLabel.text = SCILocalized(@"status_keys");
            cell.detailTextLabel.text =
                [NSString stringWithFormat:@"%lu", (unsigned long)self.all.count];
            break;
        }
        default: {
            cell.textLabel.text = SCILocalized(@"status_asked");
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",
                (unsigned long)[SCITWSwitches totalAsked]];
            break;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

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
        [self reload];
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
