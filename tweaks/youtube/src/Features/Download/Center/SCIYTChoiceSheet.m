#import "SCIYTChoiceSheet.h"
#import "../../../SCILog.h"
#import "../../../Localization/SCILocalize.h"

/// YouTube's red, which is also this tweak's accent everywhere else.
static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

@interface SCIYTChoiceSheet () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<SCIHLSVariant *> *variants;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) void (^chosen)(SCIHLSVariant *, SCIYTJobKind);
@property (nonatomic) SCIYTJobKind kind;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISegmentedControl *picker;
@end

@implementation SCIYTChoiceSheet

+ (void)presentFrom:(UIViewController *)presenter
           variants:(NSArray<SCIHLSVariant *> *)variants
              title:(NSString *)title
             chosen:(void (^)(SCIHLSVariant *, SCIYTJobKind))chosen {

    if (!presenter || !variants.count) return;

    SCIYTChoiceSheet *sheet = [[SCIYTChoiceSheet alloc] init];
    sheet.variants = variants;
    sheet.videoTitle = title;
    sheet.chosen = chosen;
    sheet.kind = SCIYTJobKindVideo;

    UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:sheet];

    // A sheet rather than a full screen: the video stays visible behind it, which is the
    // whole point of not blocking the app any more.
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = host.sheetPresentationController;
        presentation.detents = @[[UISheetPresentationControllerDetent mediumDetent],
                                 [UISheetPresentationControllerDetent largeDetent]];
        presentation.prefersGrabberVisible = YES;
        presentation.preferredCornerRadius = 22;
    }

    [presenter presentViewController:host animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"dl_choose_title");
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                       target:self
                                                       action:@selector(dismissSheet)];

    // Sound or pictures. A segmented control rather than two drawn cards: it is the
    // control iOS already uses for exactly this question, it is legible in both themes
    // without a line of styling, and it cannot lay itself out wrongly.
    self.picker = [[UISegmentedControl alloc] initWithItems:@[
        SCILocalized(@"dl_kind_video"),
        SCILocalized(@"dl_kind_audio")
    ]];
    self.picker.selectedSegmentIndex = 0;
    self.picker.selectedSegmentTintColor = SCIAccent();
    [self.picker setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}
                               forState:UIControlStateSelected];
    [self.picker addTarget:self action:@selector(kindChanged)
          forControlEvents:UIControlEventValueChanged];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];

    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self buildHeader];
}

/// The kind picker and the video's name, above the list.
///
/// Measured once and set as the table's header rather than pinned above it: a header
/// sized by systemLayoutSizeFittingSize has no relationship to anything outside the
/// table, so there is no constraint that can be unsatisfiable.
- (void)buildHeader {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 20, 8, 20);

    if (self.videoTitle.length) {
        UILabel *name = [[UILabel alloc] init];
        name.text = self.videoTitle;
        name.numberOfLines = 2;
        name.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        name.textColor = [UIColor labelColor];
        [stack addArrangedSubview:name];
    }

    [stack addArrangedSubview:self.picker];

    stack.frame = CGRectMake(0, 0, self.view.bounds.size.width,
        [stack systemLayoutSizeFittingSize:CGSizeMake(self.view.bounds.size.width, 0)
            withHorizontalFittingPriority:UILayoutPriorityRequired
                  verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height);

    self.table.tableHeaderView = stack;
}

- (void)kindChanged {
    self.kind = (self.picker.selectedSegmentIndex == 1) ? SCIYTJobKindAudio : SCIYTJobKindVideo;
    [self.table reloadData];
}

- (void)dismissSheet {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - The list

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Sound has no sizes to choose between: there is one soundtrack, and offering seven
    // identical rows of it would be a menu pretending to be a decision.
    return (self.kind == SCIYTJobKindAudio) ? 1 : (NSInteger)self.variants.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return SCILocalized(self.kind == SCIYTJobKindAudio ? @"dl_sound_header" : @"dl_quality_header");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (self.kind == SCIYTJobKindAudio) {
        cell.textLabel.text = SCILocalized(@"dl_sound_only");
        cell.detailTextLabel.text = SCILocalized(@"dl_sound_small");
        cell.imageView.image = [UIImage systemImageNamed:@"music.note"];
        cell.imageView.tintColor = SCIAccent();
        return cell;
    }

    SCIHLSVariant *variant = self.variants[(NSUInteger)indexPath.row];
    cell.textLabel.text = [variant label];
    cell.imageView.image = [UIImage systemImageNamed:@"film"];
    cell.imageView.tintColor = SCIAccent();

    // Roughly how big it will be, from the bitrate the manifest states. Approximate and
    // presented as such -- but "about 190 MB" is the difference between choosing 1080p
    // deliberately and choosing it by accident on a phone plan.
    if (variant.bandwidth > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f Mbps",
                                     variant.bandwidth / 1000000.0];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SCIHLSVariant *variant = (self.kind == SCIYTJobKindAudio)
        ? self.variants.firstObject
        : self.variants[(NSUInteger)indexPath.row];

    void (^chosen)(SCIHLSVariant *, SCIYTJobKind) = self.chosen;
    SCIYTJobKind kind = self.kind;

    [self dismissViewControllerAnimated:YES completion:^{
        if (chosen) chosen(variant, kind);
    }];
}

@end
