#import <substrate.h>
#import <objc/runtime.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCILog.h"

///
/// Auto-advance to the next reel.
///
/// Instagram already scrolls reels on its own — but only for accounts the feature
/// has been rolled out to. A count of Instagram 439.0.0 showed why the first
/// attempt never fired: it forced -autoScrollState, a selector that build does not
/// have, and forced -autoAdvanceToNextItem while leaving the actual gate untouched.
///
/// The gate is -shouldForceEnableAutoScroll on IGSundialAutoScroll, the Swift
/// engine that drives the reels feed. Instagram returns YES there itself to bypass
/// the server flag that decides whether auto-scroll is offered at all; forcing it
/// on is what makes this work on any account, and is the piece that was missing.
/// The feed controller's own -autoAdvanceToNextItem is kept as reinforcement.
///
/// No on-screen button — toggled from Reels settings — so the reels action bar and
/// its download button stay exactly where Instagram puts them.
///

static BOOL SCIWantsAutoScroll(void) {
    return [SCIUtils getBoolPref:@"reels_auto_next"];
}

// MARK: - Feed controller state

%hook IGSundialFeedViewController

- (BOOL)autoAdvanceToNextItem {
    if (SCIWantsAutoScroll()) return YES;
    return %orig;
}

%end

// MARK: - Swift engine gate

// Bound by its mangled name at load: Logos %hook cannot name a Swift class, so the
// class is fetched at runtime and the one method swizzled by hand, the same way
// the direct-message menu configuration is reached elsewhere.
static BOOL (*orig_shouldForceEnableAutoScroll)(id, SEL);

static BOOL sci_shouldForceEnableAutoScroll(id self, SEL _cmd) {
    if (SCIWantsAutoScroll()) return YES;
    return orig_shouldForceEnableAutoScroll ? orig_shouldForceEnableAutoScroll(self, _cmd) : NO;
}

%ctor {
    @autoreleasepool {
        Class engine = objc_getClass("_TtC19IGSundialAutoScroll19IGSundialAutoScroll");
        SEL gate = NSSelectorFromString(@"shouldForceEnableAutoScroll");

        // Absent on a build without the Swift auto-scroll engine: the feed-controller
        // hook above still stands, and forcing a selector that is not there is exactly
        // what broke the feature before.
        if (engine && class_getInstanceMethod(engine, gate)) {
            MSHookMessageEx(engine, gate,
                            (IMP)sci_shouldForceEnableAutoScroll,
                            (IMP *)&orig_shouldForceEnableAutoScroll);
            SCILogV(@"[Albrhi] reels auto-scroll gate hooked: %@", orig_shouldForceEnableAutoScroll ? @"yes" : @"no");
        } else {
            SCILogV(@"[Albrhi] reels auto-scroll gate not present on this build");
        }
    }
}
