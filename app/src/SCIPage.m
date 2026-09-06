#import "SCIPage.h"
#import "SCIAPI.h"

/// How long a destructive action waits before it is really sent.
///
/// Five: long enough to notice what just happened and reach the button, short enough that nobody
/// wonders whether it worked. Overridable at build time only so the preview harness can hold the
/// bar open long enough to be photographed — never changed for a shipped build.
#ifndef SCI_UNDO_SECONDS
#define SCI_UNDO_SECONDS 5
#endif

@interface SCIPage () <UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, copy, nullable) NSString *query;
@property (nonatomic, assign) NSInteger scope;
@property (nonatomic, strong, nullable) UISearchController *search;
@property (nonatomic, strong, nullable) UIView *undoBar;
@property (nonatomic, copy, nullable) void (^pending)(void);
@property (nonatomic, strong) UILabel *notice;
@property (nonatomic, copy, nullable) NSString *failure;
@property (nonatomic, assign) BOOL loading;
@end

NSString *SCIRun(NSString *text) {
    if (!text.length) return @"";
    return [NSString stringWithFormat:@"\u2068%@\u2069", text];   // FSI … PDI
}

@implementation SCIChoice

+ (instancetype)titled:(NSString *)title does:(void (^)(void))does {
    SCIChoice *choice = [[SCIChoice alloc] init];
    choice->_title = [title copy];
    choice->_does = [does copy];
    return choice;
}

+ (instancetype)dangerous:(NSString *)title does:(void (^)(void))does {
    SCIChoice *choice = [self titled:title does:does];
    choice->_dangerous = YES;
    return choice;
}

@end

@implementation SCIPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = UITableViewAutomaticDimension;

    // 64, and it has to be set: `UITableViewAutomaticDimension` does nothing without an estimate,
    // and the failure looks like a row's second line simply not existing -- which reads as the
    // code that writes it never running. That cost YouTube Music a release.
    self.table.estimatedRowHeight = 64;
    [self.view addSubview:self.table];

    self.notice = [[UILabel alloc] init];
    self.notice.translatesAutoresizingMaskIntoConstraints = NO;
    self.notice.numberOfLines = 0;
    self.notice.textAlignment = NSTextAlignmentCenter;
    self.notice.textColor = [UIColor secondaryLabelColor];
    self.notice.font = [UIFont systemFontOfSize:15];
    self.notice.hidden = YES;
    [self.view addSubview:self.notice];

    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.notice.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.notice.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.notice.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.notice.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
    ]];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pulled) forControlEvents:UIControlEventValueChanged];
    self.table.refreshControl = refresh;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)pulled { [self reload]; }

- (void)reload {
    if (self.loading) return;
    self.loading = YES;
    self.failure = nil;
    [self fetch];
}

/// «An hour ago», in words, for the copy that is being shown instead of the server's answer.
static NSString *SCIAgo(NSTimeInterval when) {
    NSInteger minutes = (NSInteger)((([NSDate date].timeIntervalSince1970 - when) / 60.0) + 0.5);
    if (minutes < 2) return @"الآن";
    if (minutes < 60) return [NSString stringWithFormat:@"قبل %ld دقيقة", (long)minutes];

    NSInteger hours = minutes / 60;
    if (hours < 24) return [NSString stringWithFormat:@"قبل %ld ساعة", (long)hours];
    return [NSString stringWithFormat:@"قبل %ld يوماً", (long)(hours / 24)];
}

- (void)loaded {
    self.loading = NO;
    self.failure = nil;

    // The title carries the age when what is on screen is not what the server just said. On the
    // title, because it is the one thing visible from every row of a long list.
    NSTimeInterval stale = [SCIAPI staleSince];
    self.navigationItem.prompt = stale > 0
        ? [NSString stringWithFormat:@"بلا اتّصال — آخر تحديث %@", SCIAgo(stale)] : nil;
    [self.table.refreshControl endRefreshing];
    [self.table reloadData];
    [self showNotice];
}

- (void)failed:(NSString *)why {
    self.loading = NO;
    self.failure = why;
    [self.table.refreshControl endRefreshing];
    [self.table reloadData];
    [self showNotice];
}

/// The one place that decides what an empty screen says.
///
/// **Three states that look identical and are not**: nothing has been asked yet, the ask failed,
/// and the ask succeeded and there is genuinely nothing. Only the second is a problem, and only
/// the first is temporary.
- (void)showNotice {
    if (self.failure.length) {
        self.notice.text = [@"⚠︎  " stringByAppendingString:self.failure];
        self.notice.hidden = NO;
        return;
    }

    if ([self rowCount] == 0) {
        // A search that found nothing and a list with nothing in it are different facts, and the
        // second sentence sends somebody looking for a fault that is not there.
        self.notice.text = self.query.length ? @"لا شيء يطابق هذا البحث."
                                             : ([self emptyMessage] ?: @"لا شيء هنا بعد.");
        self.notice.hidden = NO;
        return;
    }

    self.notice.hidden = YES;
}

#pragma mark - Subclass hooks

- (void)fetch { [self loaded]; }
- (NSInteger)rowCount { return 0; }
- (void)configure:(UITableViewCell *)cell at:(NSInteger)row { }
- (NSString *)emptyMessage { return nil; }
- (void)tapped:(NSInteger)row { }
- (void)queryChanged { }
- (NSArray<SCIChoice *> *)swipeActionsAt:(NSInteger)row { return @[]; }

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [self rowCount];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)table
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {

    NSArray<SCIChoice *> *offered = [self swipeActionsAt:path.row];
    if (!offered.count) return nil;

    NSMutableArray<UIContextualAction *> *actions = [NSMutableArray array];
    for (SCIChoice *choice in offered) {
        void (^does)(void) = choice.does;

        UIContextualAction *action = [UIContextualAction
            contextualActionWithStyle:choice.dangerous ? UIContextualActionStyleDestructive
                                                        : UIContextualActionStyleNormal
                                title:choice.title
                              handler:^(UIContextualAction *a, UIView *view,
                                        void (^done)(BOOL)) {
            does();
            done(YES);
        }];

        if (!choice.dangerous) action.backgroundColor = [UIColor systemBlueColor];
        [actions addObject:action];
    }

    UISwipeActionsConfiguration *configuration =
        [UISwipeActionsConfiguration configurationWithActions:actions];

    // **Never on a full swipe.** The first action here withdraws a licence or refuses a request,
    // and a gesture that performs the destructive one without stopping at it is a gesture that
    // costs somebody a licence on a bumpy car ride.
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"row"];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }

    // Reset before configuring. A dequeued cell carries the last row's accessory, colour and
    // detail text, and a page that sets only what it needs shows the previous row's leftovers --
    // which reads as a bug in the data.
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor labelColor];

    [self configure:cell at:path.row];
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    [self tapped:path.row];
}

#pragma mark - Small pieces

- (UITableViewCell *)cellTitled:(NSString *)title value:(NSString *)value note:(NSString *)note {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                  reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = note;
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}

- (void)sheetTitled:(NSString *)title
            message:(NSString *)message
            choices:(NSArray<SCIChoice *> *)choices {

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (SCIChoice *choice in choices) {
        UIAlertActionStyle style = choice.dangerous ? UIAlertActionStyleDestructive
                                                    : UIAlertActionStyleDefault;
        void (^does)(void) = choice.does;

        [sheet addAction:[UIAlertAction actionWithTitle:choice.title style:style
                                                handler:^(__unused UIAlertAction *chosen) {
            does();
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء"
                                              style:UIAlertActionStyleCancel handler:nil]];

    // An action sheet on iPad needs somewhere to point at or it throws. This app is an iPhone
    // app, and one line costs nothing against a crash on somebody else's device.
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)askTitled:(NSString *)title
          message:(NSString *)message
            value:(NSString *)value
         keyboard:(UIKeyboardType)keyboard
             then:(void (^)(NSString *))then {

    UIAlertController *ask =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ask addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = value;
        field.keyboardType = keyboard;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;

        // **An address, a token and a code are left-to-right text and must be laid out as such.**
        // On an Arabic phone a field is right-aligned and right-to-left by default, so a pasted
        // `https://…/x` or `ALB-4K7M-…` has its punctuation placed at the wrong end and reads
        // back reversed — and a token that *looks* wrong is retyped by hand, which is how a
        // correct paste becomes a wrong one. Only a name is left in the phone's own direction.
        if (keyboard != UIKeyboardTypeDefault) {
            field.textAlignment = NSTextAlignmentLeft;
            field.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        }
    }];

    [ask addAction:[UIAlertAction actionWithTitle:@"إلغاء"
                                            style:UIAlertActionStyleCancel handler:nil]];
    [ask addAction:[UIAlertAction actionWithTitle:@"تمام"
                                            style:UIAlertActionStyleDefault
                                          handler:^(__unused UIAlertAction *chosen) {
        then(ask.textFields.firstObject.text ?: @"");
    }]];

    [self presentViewController:ask animated:YES completion:nil];
}

- (void)badge:(NSString *)value {
    UIViewController *shown = self.navigationController ?: self;
    shown.tabBarItem.badgeValue = value;
}

#pragma mark - Copying, WhatsApp, searching

- (void)copyText:(NSString *)text {
    if (!text.length) return;

    [UIPasteboard generalPasteboard].string = text;
    [[[UINotificationFeedbackGenerator alloc] init]
        notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self say:@"نُسخ"];
}

/// Digits only, Arabic-Indic folded to ASCII.
static NSString *SCIDigits(NSString *text) {
    if (!text.length) return @"";

    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0x0660 && c <= 0x0669) c = (unichar)('0' + (c - 0x0660));   // ٠-٩
        if (c >= 0x06F0 && c <= 0x06F9) c = (unichar)('0' + (c - 0x06F0));   // ۰-۹ (Persian)
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
    }
    return digits;
}

/// The last nine, which is the part of a phone number that does not change with how it is written.
static NSString *SCITail(NSString *digits) {
    return digits.length > 9 ? [digits substringFromIndex:digits.length - 9] : digits;
}

- (BOOL)whatsApp:(NSString *)number saying:(NSString *)message {
    NSString *digits = SCIDigits(number);
    if (digits.length < 9) return NO;

    // A local number written with a leading zero is a Saudi number here. Said plainly because it
    // is an assumption: a number already carrying a country code is left exactly as it is.
    if ([digits hasPrefix:@"0"]) digits = [@"966" stringByAppendingString:[digits substringFromIndex:1]];

    NSString *escaped = [message stringByAddingPercentEncodingWithAllowedCharacters:
        [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:
        [NSString stringWithFormat:@"https://wa.me/%@?text=%@", digits, escaped ?: @""]];

    if (!url) return NO;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    return YES;
}

- (void)searchableWith:(NSString *)placeholder scopes:(NSArray<NSString *> *)scopes {
    [self searchableWith:placeholder];

    self.search.searchBar.scopeButtonTitles = scopes;
    self.search.searchBar.showsScopeBar = YES;
    self.search.searchBar.delegate = self;
}

- (void)searchBar:(UISearchBar *)bar selectedScopeButtonIndexDidChange:(NSInteger)index {
    self.scope = index;
    [self queryChanged];
    [self.table reloadData];
    [self showNotice];
}

- (void)selectScope:(NSInteger)scope {
    self.scope = scope;
    self.search.searchBar.selectedScopeButtonIndex = scope;

    // The search bar is pinned open here rather than left to a scroll: a filter that is applied
    // while its own control is off screen is a list that looks wrong for no visible reason.
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    [self queryChanged];
    [self.table reloadData];
    [self showNotice];
}

- (__kindof SCIPage *)showTab:(NSInteger)index {
    UITabBarController *tabs = self.tabBarController;
    if (index < 0 || index >= (NSInteger)tabs.viewControllers.count) return nil;

    tabs.selectedIndex = (NSUInteger)index;

    UIViewController *chosen = tabs.viewControllers[(NSUInteger)index];
    if ([chosen isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)chosen;
        [nav popToRootViewControllerAnimated:NO];
        chosen = nav.viewControllers.firstObject;
    }

    return [chosen isKindOfClass:[SCIPage class]] ? (SCIPage *)chosen : nil;
}

- (void)searchableWith:(NSString *)placeholder {
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.placeholder = placeholder;

    self.navigationItem.searchController = search;
    self.search = search;

    // Shown from the start rather than hidden until a pull. A search nobody can see is a search
    // nobody uses, and this is the one screen where finding one row among many is the whole task.
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)search {
    NSString *typed = [search.searchBar.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([typed isEqualToString:self.query ?: @""]) return;

    self.query = typed;
    [self queryChanged];
    [self.table reloadData];
    [self showNotice];
}

- (BOOL)matches:(NSArray<NSString *> *)fields {
    NSString *typed = self.query;
    if (!typed.length) return YES;

    NSString *wanted = SCITail(SCIDigits(typed));

    for (NSString *field in fields) {
        if (![field isKindOfClass:[NSString class]] || !field.length) continue;

        if ([field rangeOfString:typed options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }

        // Only when the query really is a number: three digits inside a name would otherwise
        // match every phone number on the screen.
        if (wanted.length >= 3) {
            NSString *field_digits = SCITail(SCIDigits(field));
            if (field_digits.length >= 3 &&
                ([field_digits hasSuffix:wanted] || [wanted hasSuffix:field_digits])) return YES;
        }
    }

    return NO;
}

- (void)afterUndo:(NSString *)what does:(void (^)(void))does {
    // A second action while one is waiting sends the first: they are different rows, and holding
    // both would mean the earlier one silently never happening.
    [self sendPending];

    self.pending = does;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    bar.layer.cornerRadius = 14;
    bar.layer.borderWidth = 1;
    bar.layer.borderColor = [UIColor separatorColor].CGColor;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = what;
    label.font = [UIFont systemFontOfSize:15];
    label.numberOfLines = 2;

    UIButton *undo = [UIButton buttonWithType:UIButtonTypeSystem];
    undo.translatesAutoresizingMaskIntoConstraints = NO;
    [undo setTitle:@"تراجع" forState:UIControlStateNormal];
    undo.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [undo addTarget:self action:@selector(undoPending) forControlEvents:UIControlEventTouchUpInside];

    [bar addSubview:label];
    [bar addSubview:undo];
    [self.view addSubview:bar];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [bar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                          constant:-12],

        [label.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:14],
        [label.topAnchor constraintEqualToAnchor:bar.topAnchor constant:12],
        [label.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-12],

        [undo.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:12],
        [undo.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-14],
        [undo.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
    ]];

    [self.undoBar removeFromSuperview];
    self.undoBar = bar;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCI_UNDO_SECONDS * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Only if it is still *this* one: a later action replaced the block, and sending it twice
        // is worse than the delay was.
        if (self.undoBar == bar) [self sendPending];
    });
}

- (void)sendPending {
    void (^does)(void) = self.pending;
    self.pending = nil;

    [self.undoBar removeFromSuperview];
    self.undoBar = nil;

    if (does) does();
}

- (void)undoPending {
    self.pending = nil;
    [self.undoBar removeFromSuperview];
    self.undoBar = nil;
    [self say:@"أُلغي"];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // Leaving the screen is not calling it off. The row is already gone from the list as far as
    // the reader is concerned, and a destructive action that quietly did not happen is worse than
    // one that did.
    [self sendPending];
}

- (void)say:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

+ (NSString *)dateFrom:(NSNumber *)seconds {
    // Zero is a lifetime licence, and this is the one function that knows it. A sentinel needs
    // one place that understands it rather than a rule remembered at every comparison -- the
    // panel shipped "0 valid of 3" by forgetting that in two places out of three.
    if (![seconds isKindOfClass:[NSNumber class]] || seconds.doubleValue == 0) return @"∞";

    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
    });

    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:seconds.doubleValue]];
}

@end
