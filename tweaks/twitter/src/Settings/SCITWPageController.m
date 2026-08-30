#import "SCITWPageController.h"

@interface SCITWPageController ()
@property (nonatomic, strong) SCITWPage *page;
@end

@implementation SCITWPageController

- (instancetype)initWithPage:(SCITWPage *)page {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) _page = page;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.page.title;
    self.tableView.sectionHeaderTopPadding = 0;
    [self reload];
}

/// Rebuilt on every appearance, not only on first load.
///
/// A page can be left and come back to -- turning the switch layer off on the first screen
/// and returning here should not leave a feature list that no longer applies -- and the
/// diagnostics pages exist entirely to show numbers that moved while they were closed.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (NSArray<SCITWSection *> *)buildSections {
    return [SCITWPageRegistry sectionsForPage:self.page host:self];
}

@end
