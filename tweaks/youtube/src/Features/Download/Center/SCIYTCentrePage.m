#import "SCIYTCentrePage.h"
#import "SCIYTDownloadList.h"
#import "SCIYTJob.h"
#import "../../../Localization/SCILocalize.h"

static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

@interface SCIYTCentrePage ()
@property (nonatomic, strong) NSArray<SCIYTDownloadList *> *lists;
@property (nonatomic, strong) SCIYTDownloadList *showing;
@property (nonatomic, strong) UISegmentedControl *picker;
@property (nonatomic) BOOL dismissable;
@end

@implementation SCIYTCentrePage

- (instancetype)initWithDismissButton:(BOOL)dismissable {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _dismissable = dismissable;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"dl_centre_title");
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];

    self.lists = @[[[SCIYTDownloadList alloc] initWithKind:SCIYTJobKindVideo],
                   [[SCIYTDownloadList alloc] initWithKind:SCIYTJobKindAudio]];

    self.picker = [[UISegmentedControl alloc] initWithItems:
        @[SCILocalized(@"dl_kind_video"), SCILocalized(@"dl_kind_audio")]];
    self.picker.selectedSegmentIndex = 0;
    self.picker.selectedSegmentTintColor = SCIAccent();
    [self.picker setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}
                               forState:UIControlStateSelected];
    [self.picker addTarget:self action:@selector(pickedKind)
          forControlEvents:UIControlEventValueChanged];

    // In the bar rather than under it. A control in the title position is what the app puts
    // there for exactly this -- one page, two views of it -- and it costs no vertical room
    // on a screen that is a list.
    self.navigationItem.titleView = self.picker;

    if (self.dismissable) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                           target:self
                                                           action:@selector(close)];
    }

    [self show:self.lists.firstObject];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pickedKind {
    NSUInteger at = (NSUInteger)MAX(self.picker.selectedSegmentIndex, 0);
    if (at >= self.lists.count) return;
    [self show:self.lists[at]];
}

/// Swaps which list is on screen, as a proper child.
///
/// Containment and not just -addSubview:, because a list is a view controller with a table
/// that wants to know when it appeared -- added as a bare view it never receives that, and
/// the rows come back stale after the first switch.
- (void)show:(SCIYTDownloadList *)list {
    if (self.showing == list) return;

    if (self.showing) {
        [self.showing willMoveToParentViewController:nil];
        [self.showing.view removeFromSuperview];
        [self.showing removeFromParentViewController];
    }

    [self addChildViewController:list];
    list.view.frame = self.view.bounds;
    list.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:list.view];
    [list didMoveToParentViewController:self];

    self.showing = list;
}

@end
