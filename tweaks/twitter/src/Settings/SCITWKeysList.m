#import "SCITWKeysList.h"
#import "Localization/SCILocalize.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Features/Switches/SCITWFeatures.h"

@interface SCITWKeysList () <UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<SCITWSwitchRecord *> *all;
@property (nonatomic, strong) NSArray<SCITWSwitchRecord *> *shown;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, assign) BOOL changedOnly;
@end

@implementation SCITWKeysList

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"section_keys");

    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.placeholder = SCILocalized(@"search_placeholder");
    search.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
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

    [self reload];
}

// Re-read every time this screen comes on top, not only when it is first built. It is
// pushed once and can stay in the navigation stack while X keeps asking new keys in the
// background -- a page that only ever showed what existed at the moment it was tapped
// would fall behind the live count on the row that opened it.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.query = searchController.searchBar.text;
    [self reload];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)scope {
    self.changedOnly = (scope == 1);
    [self reload];
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.shown.count ?: 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return SCILocalized(@"keys_footer");
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

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
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
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
        [NSString stringWithFormat:SCILocalized(@"detail_asked"), (unsigned long)record.asked]];
    cell.detailTextLabel.textColor = (override != SCITWOverrideNone)
        ? [UIColor systemBlueColor]
        : (owner ? [UIColor systemTealColor] : [UIColor secondaryLabelColor]);

    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.shown.count) return;

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

@end
