#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCILKQuickSave.h"
#import "SCILKMedia.h"
#import "SCILKDownload.h"
#import "../../Tweak.h"
#import "../../SCILog.h"

///
/// A small circle, bottom-trailing, that saves the newest moment in one tap.
///
/// The two-finger hold already reaches every moment through a list, and stays -- this is
/// not a replacement for it, it is the shortcut for the ordinary case: a friend's photo
/// just arrived, and saving *that one* is what a tap here is for. It always saves the
/// newest capture, not whatever the app happens to be showing, because the app is not
/// something this code can read -- see SCILKMedia.h.
///
/// Attached to the window the same way the gesture is, for the same reason: Locket is a
/// SwiftUI app end to end, and a window is the one thing that outlives every screen inside
/// it without this code needing to know what any of them are.
///

static char kSCIQuickSaveButton;
static char kSCIQuickSaveTimer;


@interface SCILKQuickSaveTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
- (void)refresh:(NSTimer *)timer;
@end

@implementation SCILKQuickSaveTarget

+ (instancetype)shared {
    static SCILKQuickSaveTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCILKQuickSaveTarget alloc] init]; });
    return shared;
}

- (void)tapped:(UIButton *)button {
    SCILKMediaItem *item = [SCILKMedia recent].firstObject;
    if (!item) return;   // the button is hidden whenever this would be nil; belt and braces

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium]
        impactOccurred];

    [SCILKDownload save:item];
}

/// Hidden with nothing to save, shown once there is something -- checked on a timer
/// rather than from a notification, because SCILKMedia has none to post and a moment
/// arrives by a network response this code never sees finish.
- (void)refresh:(NSTimer *)timer {
    UIButton *button = (UIButton *)timer.userInfo;
    if (!button.window) { [timer invalidate]; return; }

    button.hidden = ([SCILKMedia recent].count == 0);
}

@end


static void SCILKAttachQuickSaveButton(UIWindow *window) {
    if (!window) return;

    if (objc_getAssociatedObject(window, &kSCIQuickSaveButton)) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.hidden = YES;   // until the first refresh finds something

    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:22
                                                        weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"
                             withConfiguration:weight]
            forState:UIControlStateNormal];
    button.tintColor = SCIAccent();
    button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.82];
    button.layer.cornerRadius = 25;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOpacity = 0.35;
    button.layer.shadowRadius = 6;
    button.layer.shadowOffset = CGSizeMake(0, 2);

    [button addTarget:[SCILKQuickSaveTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    button.translatesAutoresizingMaskIntoConstraints = NO;
    [window addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor
                                               constant:-16],
        [button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor
                                             constant:-28],
        [button.widthAnchor constraintEqualToConstant:50],
        [button.heightAnchor constraintEqualToConstant:50],
    ]];

    objc_setAssociatedObject(window, &kSCIQuickSaveButton, button, OBJC_ASSOCIATION_RETAIN);

    // Checked twice a second. Cheap -- an array count -- and the timer stops itself the
    // moment its button is no longer in a window, so a window that goes away does not
    // leak one running forever.
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                       target:[SCILKQuickSaveTarget shared]
                                                     selector:@selector(refresh:)
                                                     userInfo:button
                                                      repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(window, &kSCIQuickSaveTimer, timer, OBJC_ASSOCIATION_RETAIN);

    SCILogV(@"quick-save button attached to %@", window);
}


%group QuickSave

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    SCILKAttachQuickSaveButton(self);
}

%end

%end


void SCILKInstallQuickSave(void) {
    %init(QuickSave);
}
