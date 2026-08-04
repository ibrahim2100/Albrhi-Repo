#import "SCIYTCentrePage.h"
#import "../../../Tweak.h"
#import "SCIYTDownloadList.h"
#import "SCIYTMiniPlayer.h"
#import "SCIYTPlayer.h"
#import "SCIYTJob.h"
#import "../../../Localization/SCILocalize.h"


@interface SCIYTCentrePage ()
@property (nonatomic, strong) NSArray<SCIYTDownloadList *> *lists;
@property (nonatomic, strong) SCIYTDownloadList *showing;
@property (nonatomic, strong) UISegmentedControl *picker;
@property (nonatomic) BOOL dismissable;
@property (nonatomic, strong) SCIYTMiniPlayer *mini;
@property (nonatomic, strong) NSLayoutConstraint *miniHeight;
@property (nonatomic, strong) CAGradientLayer *ground;
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
    self.view.backgroundColor = [UIColor blackColor];

    // One surface, lit from the top.
    //
    // A flat near-black behind an inset-grouped table was two greys with a gap between them,
    // and it read as a settings screen with pictures in it. A single graded ground with the
    // cards floating on it is the shape this actually is: a shelf of things, not a form.
    CAGradientLayer *ground = [CAGradientLayer layer];
    ground.colors = @[(id)[UIColor colorWithWhite:0.13 alpha:1].CGColor,
                      (id)[UIColor colorWithWhite:0.04 alpha:1].CGColor];
    ground.startPoint = CGPointMake(0.5, 0);
    ground.endPoint = CGPointMake(0.5, 0.65);
    [self.view.layer insertSublayer:ground atIndex:0];
    self.ground = ground;

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

    [self buildMiniPlayer];
    [self show:self.lists.firstObject];
}


/// The strip along the bottom, and the room it takes from the list.
///
/// Added to the page rather than to each list, because the lists are swapped and a bar that
/// belonged to one would vanish on switching to the other while its music kept playing.
- (void)buildMiniPlayer {
    self.mini = [[SCIYTMiniPlayer alloc] initWithFrame:CGRectZero];
    self.mini.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mini];

    self.miniHeight = [self.mini.heightAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.mini.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mini.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mini.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        self.miniHeight,
    ]];

    // The list gets its last rows back when the bar goes away. A strip overlapping the final
    // row is the sort of thing that is invisible until the row you want is the last one.
    __weak __typeof(self) weakSelf = self;
    self.mini.miniPlayerVisibilityChanged = ^(BOOL visible) {
        weakSelf.miniHeight.constant = visible ? 62 : 0;
        [weakSelf inset:visible ? 62 : 0];
    };

    // Applied once here as well. The bar decides whether to show itself while it is being
    // built, which is before this block exists to be told -- so opening the Centre with
    // something already playing would leave a bar of no height with music coming out of it.
    BOOL playing = [SCIYTPlayer isActive];
    self.miniHeight.constant = playing ? 62 : 0;
    [self inset:playing ? 62 : 0];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.ground.frame = self.view.bounds;
}

- (void)inset:(CGFloat)bottom {
    for (SCIYTDownloadList *list in self.lists) {
        UIEdgeInsets insets = list.tableView.contentInset;
        insets.bottom = bottom;
        list.tableView.contentInset = insets;
        list.tableView.verticalScrollIndicatorInsets = insets;
    }
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
    // Under the mini bar, which was added first and would otherwise end up behind every list
    // swapped in after it -- playing, tappable in theory, and invisible.
    if (self.mini) {
        [self.view insertSubview:list.view belowSubview:self.mini];
    } else {
        [self.view addSubview:list.view];
    }
    [list didMoveToParentViewController:self];

    self.showing = list;
}

@end
