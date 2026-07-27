#import <substrate.h>
#import <objc/runtime.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCILog.h"

///
/// Auto-advance to the next reel — across Instagram versions.
///
/// Reels auto-scroll is gated by a handful of BOOL getters, and which ones a build
/// has differs. Counting them in the real 410 and 439 binaries settled it:
///
///   -isAutoAdvanceEnabled        both       the gate that decides it at all
///   -autoAdvanceToNextItem       both       the feed's own state
///   -shouldForceEnableAutoScroll 439 only    the override that skips the server flag
///   -autoScrollState             410 only    the old feed getter
///
/// The first version forced -autoScrollState (gone in 439) and left -isAutoAdvanceEnabled
/// — the one gate present on both — untouched, which is why it never scrolled. This
/// forces every gate that actually exists, on whichever class owns it, and does it
/// by hand with a per-method guard so a selector a build does not have is skipped
/// rather than added as a dead method. Forcing a selector that is not there was the
/// original mistake.
///
/// The gate names came from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3),
/// which ships a separate build per Instagram version for exactly this reason; here
/// one build carries all of them and lets the guard pick. The mechanism is Albrhi's.
///
/// No on-screen button — toggled from Reels settings — so the reels action bar and
/// its download button stay where Instagram puts them.
///

static BOOL SCIWantsAutoScroll(void) {
    return [SCIUtils getBoolPref:@"reels_auto_next"];
}

// MARK: - Forced gates

// One trampoline for every gate. When the feature is on it forces YES; when off it
// must return the real answer, so each install keeps its own original, found by the
// selector plus the class the call actually belongs to (a selector can live on more
// than one of the classes below).
#define SCI_MAX_GATES 8
static struct { Class cls; SEL selector; IMP original; } sGates[SCI_MAX_GATES];
static size_t sGateCount = 0;

static BOOL SCIGateTrampoline(id self, SEL _cmd) {
    if (SCIWantsAutoScroll()) return YES;

    for (size_t i = 0; i < sGateCount; i++) {
        if (sGates[i].selector == _cmd && [self isKindOfClass:sGates[i].cls] && sGates[i].original) {
            return ((BOOL (*)(id, SEL))sGates[i].original)(self, _cmd);
        }
    }
    return NO;
}

static void SCIForceGate(Class cls, NSString *name) {
    if (!cls || sGateCount >= SCI_MAX_GATES) return;

    SEL selector = NSSelectorFromString(name);
    // Only where the method genuinely exists: class_getInstanceMethod walks the
    // superclasses too, so an inherited gate still counts, and a build without it is
    // left alone instead of gaining a method nothing calls.
    if (!selector || !class_getInstanceMethod(cls, selector)) return;

    IMP original = NULL;
    MSHookMessageEx(cls, selector, (IMP)SCIGateTrampoline, &original);
    if (!original) return;

    sGates[sGateCount].cls = cls;
    sGates[sGateCount].selector = selector;
    sGates[sGateCount].original = original;
    sGateCount++;
}

%ctor {
    @autoreleasepool {
        // The feed controller carries the state getters; the Swift engine carries the
        // force override. isAutoAdvanceEnabled can sit on either, so it is offered to
        // both and the guard installs it wherever it really is.
        Class feed = objc_getClass("IGSundialFeedViewController");
        Class engine = objc_getClass("_TtC19IGSundialAutoScroll19IGSundialAutoScroll");

        SCIForceGate(feed, @"isAutoAdvanceEnabled");
        SCIForceGate(feed, @"autoAdvanceToNextItem");
        SCIForceGate(feed, @"autoScrollState");                // 410

        SCIForceGate(engine, @"shouldForceEnableAutoScroll");  // 439
        SCIForceGate(engine, @"isAutoAdvanceEnabled");
        SCIForceGate(engine, @"autoAdvanceToNextItem");

        SCILogV(@"[Albrhi] reels auto-scroll gates forced: %zu", sGateCount);
    }
}
