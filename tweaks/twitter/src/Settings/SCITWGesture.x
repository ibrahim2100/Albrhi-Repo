#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITWSettings.h"
#import "SCITWGesture.h"
#import "SCILog.h"

///
/// Two fingers, held. The only way into this tweak's screen.
///
/// Attached to X's own window rather than to a view controller, for the reason the header
/// gives: a window is one thing that exists for the whole life of the app, and every screen
/// X has is inside it. Hooking a screen would mean picking one, and then the gesture works
/// on the timeline and not in a profile, which is worse than not having it.
///
/// `-makeKeyAndVisible` is where it goes because it is called once per window and after the
/// window has a root -- a recogniser added earlier can be lost when the root is replaced.
///

@interface SCITWGestureTarget : NSObject
+ (instancetype)shared;
- (void)fired:(UILongPressGestureRecognizer *)recogniser;
@end

@implementation SCITWGestureTarget

+ (instancetype)shared {
    static SCITWGestureTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[SCITWGestureTarget alloc] init];
    });
    return shared;
}

- (void)fired:(UILongPressGestureRecognizer *)recogniser {
    // Began, not ended. Waiting for the fingers to lift means the screen appears after the
    // gesture is over and feels like a delayed accident; appearing while they are still
    // down is what every long press in iOS does.
    if (recogniser.state != UIGestureRecognizerStateBegan) return;

    [SCITWSettings present];
}

@end


void SCITWAttachGesture(UIWindow *window) {
    if (!window) return;

    // Once per window. Windows are made more than once in X -- alerts and the media viewer
    // each get their own -- and a second recogniser on the same one fires the gesture twice
    // from a single hold.
    static const char *marker = "SCITWGesture";
    if (objc_getAssociatedObject(window, marker)) return;
    objc_setAssociatedObject(window, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCITWGestureTarget shared]
                                                       action:@selector(fired:)];
    hold.numberOfTouchesRequired = 2;
    hold.minimumPressDuration = 0.65;

    // The one line that keeps X working normally.
    //
    // Without it, every touch this recogniser is watching is delayed while it decides, and
    // a timeline that hesitates on each scroll is how a tweak gets uninstalled. It also
    // means X's own gestures are never cancelled by ours.
    hold.cancelsTouchesInView = NO;
    hold.delaysTouchesBegan = NO;
    hold.delaysTouchesEnded = NO;

    [window addGestureRecognizer:hold];
    SCILogV(@"gesture attached to %@", window);
}


%group Gesture

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    SCITWAttachGesture(self);
}

%end

%end


void SCITWInstallGesture(void) {
    %init(Gesture);
}
