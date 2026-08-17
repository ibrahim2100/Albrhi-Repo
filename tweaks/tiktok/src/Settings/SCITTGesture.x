#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTGesture.h"
#import "SCITTStatus.h"
#import "../SCILog.h"

///
/// Two fingers, held. The same technique Locket's own gesture uses, for the same
/// reason: attached to the app's own window rather than to any one screen, since a
/// window lives for the whole app and every screen sits inside it.
///

@interface SCITTGestureTarget : NSObject
+ (instancetype)shared;
- (void)fired:(UILongPressGestureRecognizer *)recogniser;
@end

@implementation SCITTGestureTarget

+ (instancetype)shared {
    static SCITTGestureTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITTGestureTarget alloc] init]; });
    return shared;
}

- (void)fired:(UILongPressGestureRecognizer *)recogniser {
    if (recogniser.state == UIGestureRecognizerStateBegan) [SCITTStatus present];
}

@end


static void SCITTAttachGesture(UIWindow *window) {
    if (!window) return;

    static const char *marker = "SCITTGesture";
    if (objc_getAssociatedObject(window, marker)) return;
    objc_setAssociatedObject(window, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCITTGestureTarget shared]
                                                      action:@selector(fired:)];
    hold.numberOfTouchesRequired = 2;
    hold.minimumPressDuration = 0.65;

    // Without this every touch this watches is delayed while it decides, and it never
    // cancels TikTok's own gestures underneath it.
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
    SCITTAttachGesture(self);
}

%end

%end


void SCITTInstallGesture(void) {
    %init(Gesture);
}
