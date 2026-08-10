#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCILKGesture.h"
#import "SCILKStatus.h"
#import "SCILog.h"

///
/// Two fingers, held. The only way into the status screen.
///
/// Attached to Locket's own window, for the reason the header gives: a window lives for the
/// whole app and every screen is inside it, while a Flutter app has no native settings view
/// to add a row to. Added in `-makeKeyAndVisible`, once per window.
///

@interface SCILKGestureTarget : NSObject
+ (instancetype)shared;
- (void)fired:(UILongPressGestureRecognizer *)recogniser;
@end

@implementation SCILKGestureTarget

+ (instancetype)shared {
    static SCILKGestureTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCILKGestureTarget alloc] init]; });
    return shared;
}

- (void)fired:(UILongPressGestureRecognizer *)recogniser {
    if (recogniser.state == UIGestureRecognizerStateBegan) [SCILKStatus present];
}

@end


static void SCILKAttachGesture(UIWindow *window) {
    if (!window) return;

    static const char *marker = "SCILKGesture";
    if (objc_getAssociatedObject(window, marker)) return;
    objc_setAssociatedObject(window, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCILKGestureTarget shared]
                                                      action:@selector(fired:)];
    hold.numberOfTouchesRequired = 2;
    hold.minimumPressDuration = 0.65;

    // The one line that keeps Locket working normally: without it every touch this watches
    // is delayed while it decides, and it never cancels the app's own gestures.
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
    SCILKAttachGesture(self);
}

%end

%end


void SCILKInstallGesture(void) {
    %init(Gesture);
}
