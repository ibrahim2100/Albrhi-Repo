#import "SCIPage.h"
#import "SCIAPI.h"

@interface SCIPage ()
@property (nonatomic, strong) UITableView *table;
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

- (void)loaded {
    self.loading = NO;
    self.failure = nil;
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
        self.notice.text = [self emptyMessage] ?: @"لا شيء هنا بعد.";
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

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [self rowCount];
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
