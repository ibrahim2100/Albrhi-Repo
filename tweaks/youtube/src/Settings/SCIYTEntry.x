#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../UI/SCIYTSettingsController.h"
#import "../Diagnostics/SCIYTDiagnostics.h"
#import <objc/runtime.h>

///
/// How the panel is opened: a two-finger long press, anywhere.
///
/// The gesture is attached to UIWindow, not to any YouTube view, and that is the
/// point. Two attempts at a settings entry failed against YouTube's own classes, and
/// a survey of the tweak this project studied for hook points found nineteen of its
/// target names are not classes in this build at all -- including YTAppViewController,
/// the obvious place to hang something like this. An entry point that is itself a
/// guess is an entry point that can vanish without a word.
///
/// UIWindow is UIKit. It cannot be missing, it cannot be renamed, and it does not care
/// which app it is in.
///
/// Two fingers rather than one: YouTube uses single long presses of its own -- on a
/// video cell, on the player, in comments -- and taking one would either fight them or
/// be swallowed by them.
///

/// A gesture recogniser needs a target that outlives the gesture, and a window is not
/// ours to hang state on. One shared object, created once.
@interface SCIYTEntryTarget : NSObject
+ (instancetype)shared;
@end

@implementation SCIYTEntryTarget

+ (instancetype)shared {
    static SCIYTEntryTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[SCIYTEntryTarget alloc] init];
    });
    return shared;
}

- (void)pressed:(UILongPressGestureRecognizer *)recognizer {
    // Began, not ended: the panel should appear while the fingers are still down, the
    // way a long press behaves everywhere else. Ended would also fire a second time on
    // release.
    if (recognizer.state != UIGestureRecognizerStateBegan) return;

    SCILogV(@"entry: two-finger long press");
    [SCIYTSettingsController present];
}

@end


static char kSCIGestureAttached;

static void SCIArmPanelGesture(UIWindow *window) {
    if (!window || objc_getAssociatedObject(window, &kSCIGestureAttached)) return;

    // Marked on the window rather than tracked in a global flag. Windows come and go,
    // and a keyboard or an alert gets one of its own, so every real window is armed
    // exactly once and a transient one arming itself costs nothing.
    objc_setAssociatedObject(window, &kSCIGestureAttached, @YES, OBJC_ASSOCIATION_RETAIN);

    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCIYTEntryTarget shared]
                                                     action:@selector(pressed:)];
    press.numberOfTouchesRequired = 2;
    press.minimumPressDuration = 0.45;

    // Never swallow the touch. Whatever this gesture is laid over must keep working
    // exactly as it did, whether or not the recogniser fires.
    press.cancelsTouchesInView = NO;
    press.delaysTouchesBegan = NO;
    press.delaysTouchesEnded = NO;

    [window addGestureRecognizer:press];

    SCILogV(@"entry: gesture armed on %@", [window class]);
}

%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    SCIArmPanelGesture(self);
}

%end


%hook YTAppSettingsGroupPresentationData

+ (NSArray *)orderedGroups {
    NSArray *groups = %orig;

    // Read and reported, never modified. Kept because it costs one call and records
    // what a settings section would have to fit into if one is attempted again --
    // measured from the build in hand rather than assumed, which is the part both
    // earlier attempts skipped.
    [SCIYTDiagnostics recordSettingsGroups:groups];

    return groups;
}

%end
