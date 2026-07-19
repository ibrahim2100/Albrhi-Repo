#import "SCIDownloadCenterViewController.h"
#import "SCIDownloadQueue.h"
#import "SCIDownloadCell.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

typedef NS_ENUM(NSInteger, SCIDownloadSort) {
    SCIDownloadSortNewest,
    SCIDownloadSortOldest,
    SCIDownloadSortName,
    SCIDownloadSortSize
};

@interface SCIDownloadCenterViewController () <UITableViewDataSource, UITableViewDelegate,
                                               UISearchResultsUpdating, UISearchBarDelegate,
                                               SCIDownloadCellDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIView *emptyStateView;

@property (nonatomic, copy) NSArray<SCIDownloadJob *> *activeRows;
@property (nonatomic, copy) NSArray<SCIDownloadJob *> *historyRows;

@property (nonatomic) SCIDownloadSort sort;
@property (nonatomic) SCIDownloadMediaKind kindFilter;

@end

@implementation SCIDownloadCenterViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"dl_center_title");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.view.tintColor = [SCIUtils SCIColor_Primary];

    self.sort = SCIDownloadSortNewest;
    self.kindFilter = SCIDownloadMediaKindUnknown;  // "all" — no job is ever created as Unknown-only

    if ([SCILocalize isRTL]) {
        self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }

    [self buildTableView];
    [self buildSearch];
    [self buildNavigationItems];
    [self buildToolbar];
    [self buildEmptyState];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queueChanged:)
                                                 name:SCIDownloadQueueDidChangeNotification
                                               object:nil];

    [self reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.navigationController setToolbarHidden:YES animated:animated];
}

// MARK: - Construction

- (void)buildTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64.0;
    self.tableView.semanticContentAttribute = self.view.semanticContentAttribute;

    [self.tableView registerClass:[SCIDownloadCell class]
           forCellReuseIdentifier:[SCIDownloadCell reuseIdentifier]];

    [self.view addSubview:self.tableView];
}

- (void)buildSearch {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = SCILocalized(@"dl_search_placeholder");
    self.searchController.searchBar.delegate = self;

    // Scope bar doubles as the media-kind filter.
    self.searchController.searchBar.scopeButtonTitles = @[
        SCILocalized(@"dl_scope_all"),
        SCILocalized(@"dl_kind_photo"),
        SCILocalized(@"dl_kind_video"),
        SCILocalized(@"dl_kind_audio")
    ];

    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)buildNavigationItems {
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"]
                                          menu:[self sortMenu]];
}

- (void)buildToolbar {
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];

    UIBarButtonItem *pauseAll = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"pause.circle"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(pauseAllTapped)];
    pauseAll.accessibilityLabel = SCILocalized(@"dl_pause_all");

    UIBarButtonItem *resumeAll = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"play.circle"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(resumeAllTapped)];
    resumeAll.accessibilityLabel = SCILocalized(@"dl_resume_all");

    UIBarButtonItem *clear = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(clearHistoryTapped)];
    clear.tintColor = [UIColor systemRedColor];
    clear.accessibilityLabel = SCILocalized(@"dl_clear_history");

    self.toolbarItems = @[pauseAll, flexible, resumeAll, flexible, clear];
}

- (void)buildEmptyState {
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:52.0
                                                                                  weight:UIImageSymbolWeightLight]]];
    glyph.tintColor = [UIColor tertiaryLabelColor];

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"dl_empty_title");
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.textColor = [UIColor secondaryLabelColor];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = SCILocalized(@"dl_empty_sub");
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    subtitle.textColor = [UIColor tertiaryLabelColor];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[glyph, title, subtitle]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.hidden = YES;

    [self.emptyStateView addSubview:stack];
    [self.view addSubview:self.emptyStateView];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyStateView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.75],

        [stack.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor]
    ]];
}

- (UIMenu *)sortMenu {
    __weak typeof(self) weakSelf = self;

    NSArray *titles = @[
        SCILocalized(@"dl_sort_newest"),
        SCILocalized(@"dl_sort_oldest"),
        SCILocalized(@"dl_sort_name"),
        SCILocalized(@"dl_sort_size")
    ];

    NSMutableArray<UIAction *> *actions = [NSMutableArray array];

    [titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger index, BOOL *stop) {
        UIAction *action = [UIAction actionWithTitle:title
                                               image:nil
                                          identifier:nil
                                             handler:^(__kindof UIAction *sender) {
            weakSelf.sort = (SCIDownloadSort)index;
            weakSelf.navigationItem.rightBarButtonItem.menu = [weakSelf sortMenu];

            [weakSelf reloadData];
        }];

        action.state = (self.sort == (SCIDownloadSort)index) ? UIMenuElementStateOn : UIMenuElementStateOff;

        [actions addObject:action];
    }];

    return [UIMenu menuWithTitle:SCILocalized(@"dl_sort_title") children:actions];
}

// MARK: - Data

- (void)queueChanged:(NSNotification *)note {
    SCIDownloadJob *job = note.userInfo[@"job"];

    // A progress tick on a visible, already-listed row updates just that cell.
    // Anything structural (new job, state change, removal) goes through a reload.
    if (job && job.state == SCIDownloadStateDownloading) {
        NSInteger row = [self.activeRows indexOfObject:job];

        if (row != NSNotFound) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
            SCIDownloadCell *cell = (SCIDownloadCell *)[self.tableView cellForRowAtIndexPath:indexPath];

            [cell applyProgressFromJob:job];

            return;
        }
    }

    [self reloadData];
}

- (void)reloadData {
    NSString *query = self.searchController.searchBar.text;

    self.activeRows = [self filter:[SCIDownloadQueue shared].activeJobs query:query];
    self.historyRows = [self filter:[SCIDownloadQueue shared].history query:query];

    BOOL isEmpty = (self.activeRows.count == 0 && self.historyRows.count == 0);
    self.emptyStateView.hidden = !isEmpty;
    self.tableView.hidden = isEmpty;

    [self.tableView reloadData];
}

- (NSArray<SCIDownloadJob *> *)filter:(NSArray<SCIDownloadJob *> *)jobs query:(NSString *)query {
    NSMutableArray<SCIDownloadJob *> *result = [NSMutableArray array];

    for (SCIDownloadJob *job in jobs) {
        if (self.kindFilter != SCIDownloadMediaKindUnknown && job.mediaKind != self.kindFilter) continue;

        if ([query length]) {
            BOOL matchesName = [job.displayName localizedCaseInsensitiveContainsString:query];
            BOOL matchesSource = [job.sourceLabel localizedCaseInsensitiveContainsString:query];

            if (!matchesName && !matchesSource) continue;
        }

        [result addObject:job];
    }

    return [self sorted:result];
}

- (NSArray<SCIDownloadJob *> *)sorted:(NSArray<SCIDownloadJob *> *)jobs {
    switch (self.sort) {
        case SCIDownloadSortNewest:
            return [jobs sortedArrayUsingComparator:^NSComparisonResult(SCIDownloadJob *a, SCIDownloadJob *b) {
                return [b.createdAt compare:a.createdAt];
            }];

        case SCIDownloadSortOldest:
            return [jobs sortedArrayUsingComparator:^NSComparisonResult(SCIDownloadJob *a, SCIDownloadJob *b) {
                return [a.createdAt compare:b.createdAt];
            }];

        case SCIDownloadSortName:
            return [jobs sortedArrayUsingComparator:^NSComparisonResult(SCIDownloadJob *a, SCIDownloadJob *b) {
                return [a.displayName localizedStandardCompare:b.displayName];
            }];

        case SCIDownloadSortSize:
            return [jobs sortedArrayUsingComparator:^NSComparisonResult(SCIDownloadJob *a, SCIDownloadJob *b) {
                if (a.bytesReceived == b.bytesReceived) return NSOrderedSame;
                return (a.bytesReceived > b.bytesReceived) ? NSOrderedAscending : NSOrderedDescending;
            }];
    }
}

- (SCIDownloadJob *)jobAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *source = (indexPath.section == 0) ? self.activeRows : self.historyRows;

    return (indexPath.row < source.count) ? source[indexPath.row] : nil;
}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? self.activeRows.count : self.historyRows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return self.activeRows.count ? SCILocalized(@"dl_section_active") : nil;
    }

    return self.historyRows.count ? SCILocalized(@"dl_section_history") : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 1 || !self.historyRows.count) return nil;

    int64_t total = [[SCIDownloadQueue shared] totalBytesDownloaded];
    NSString *size = [NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleFile];

    return [NSString stringWithFormat:SCILocalized(@"dl_total_footer"), size];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIDownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCIDownloadCell reuseIdentifier]
                                                            forIndexPath:indexPath];
    cell.delegate = self;

    SCIDownloadJob *job = [self jobAtIndexPath:indexPath];
    if (job) [cell configureWithJob:job accentColor:[SCIUtils SCIColor_Primary]];

    return cell;
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SCIDownloadJob *job = [self jobAtIndexPath:indexPath];
    if (job.state != SCIDownloadStateCompleted || !job.localURL) return;

    [SCIUtils showQuickLookVC:@[job.localURL]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCIDownloadJob *job = [self jobAtIndexPath:indexPath];
    if (!job) return nil;

    __weak typeof(self) weakSelf = self;

    UIContextualAction *remove =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:nil
                                              handler:^(UIContextualAction *action, UIView *source, void (^done)(BOOL)) {
        if (job.isActive) {
            [[SCIDownloadQueue shared] cancelJob:job];
        } else {
            [[SCIDownloadQueue shared] removeJobFromHistory:job];
        }

        [weakSelf reloadData];
        done(YES);
    }];

    remove.image = [UIImage systemImageNamed:job.isActive ? @"xmark" : @"trash"];

    if (job.state != SCIDownloadStateFailed && job.state != SCIDownloadStateCancelled) {
        return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
    }

    UIContextualAction *retry =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:nil
                                              handler:^(UIContextualAction *action, UIView *source, void (^done)(BOOL)) {
        [[SCIDownloadQueue shared] retryJob:job];

        [weakSelf reloadData];
        done(YES);
    }];

    retry.image = [UIImage systemImageNamed:@"arrow.clockwise"];
    retry.backgroundColor = [SCIUtils SCIColor_Primary];

    return [UISwipeActionsConfiguration configurationWithActions:@[remove, retry]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                    point:(CGPoint)point {
    SCIDownloadJob *job = [self jobAtIndexPath:indexPath];
    if (!job) return nil;

    __weak typeof(self) weakSelf = self;

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        NSMutableArray<UIAction *> *actions = [NSMutableArray array];

        if (job.state == SCIDownloadStateCompleted && job.localURL) {
            [actions addObject:[UIAction actionWithTitle:SCILocalized(@"dl_share")
                                                   image:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction *sender) {
                [SCIUtils showShareVC:job.localURL];
            }]];
        }

        [actions addObject:[UIAction actionWithTitle:SCILocalized(@"dl_copy_link")
                                               image:[UIImage systemImageNamed:@"link"]
                                          identifier:nil
                                             handler:^(__kindof UIAction *sender) {
            [UIPasteboard generalPasteboard].string = job.remoteURL.absoluteString;
        }]];

        UIAction *remove = [UIAction actionWithTitle:SCILocalized(@"dl_remove")
                                               image:[UIImage systemImageNamed:@"trash"]
                                          identifier:nil
                                             handler:^(__kindof UIAction *sender) {
            if (job.isActive) {
                [[SCIDownloadQueue shared] cancelJob:job];
            } else {
                [[SCIDownloadQueue shared] removeJobFromHistory:job];
            }

            [weakSelf reloadData];
        }];
        remove.attributes = UIMenuElementAttributesDestructive;

        [actions addObject:remove];

        return [UIMenu menuWithTitle:job.displayName children:actions];
    }];
}

// MARK: - SCIDownloadCellDelegate

- (void)downloadCellDidTapAction:(SCIDownloadCell *)cell {
    SCIDownloadJob *job = cell.job;
    if (!job) return;

    switch (job.state) {
        case SCIDownloadStateDownloading: [[SCIDownloadQueue shared] pauseJob:job];  break;
        case SCIDownloadStatePaused:      [[SCIDownloadQueue shared] resumeJob:job]; break;
        case SCIDownloadStateQueued:      [[SCIDownloadQueue shared] cancelJob:job]; break;
        case SCIDownloadStateFailed:
        case SCIDownloadStateCancelled:   [[SCIDownloadQueue shared] retryJob:job];  break;
        case SCIDownloadStateCompleted:   break;
    }
}

// MARK: - Toolbar actions

- (void)pauseAllTapped {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];

    [[SCIDownloadQueue shared] pauseAll];
}

- (void)resumeAllTapped {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];

    [[SCIDownloadQueue shared] resumeAll];
}

- (void)clearHistoryTapped {
    UIAlertController *confirm =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_clear_history")
                                             message:SCILocalized(@"dl_clear_history_message")
                                      preferredStyle:UIAlertControllerStyleActionSheet];

    [confirm addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dl_clear_history")
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
        [[SCIDownloadQueue shared] clearHistory];
        [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
    }]];

    [confirm addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                                 style:UIAlertActionStyleCancel
                                               handler:nil]];

    // Anchored for iPad, where an unanchored action sheet is fatal.
    confirm.popoverPresentationController.barButtonItem = self.toolbarItems.lastObject;

    [self presentViewController:confirm animated:YES completion:nil];
}

// MARK: - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    switch (selectedScope) {
        case 1:  self.kindFilter = SCIDownloadMediaKindPhoto; break;
        case 2:  self.kindFilter = SCIDownloadMediaKindVideo; break;
        case 3:  self.kindFilter = SCIDownloadMediaKindAudio; break;
        default: self.kindFilter = SCIDownloadMediaKindUnknown; break;
    }

    [self reloadData];
}

@end
