#import <substrate.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

///
/// Auto-advance to the next reel — across Instagram versions.
///
/// Walking the class metadata of the real 410 and 439 binaries showed the whole
/// picture. IGSundialFeedViewController carries its own auto-scroll machinery, and
/// which gate actually decides it differs by build:
///
///   -isAutoAdvanceEnabled / -autoAdvanceToNextItem   both     state getters
///   -shouldForceEnableAutoScroll                     439      Swift-engine override
///   -autoScrollState                                 410      old feed getter
///   -_isAutoScrollingBlocked                         410      the real blocker
///   -_shouldAutoScrollToObject:exclusionRule:        410      the real decision
///   -advanceToNextItemDisabled                       439      a disable flag
///
/// Forcing only the state getters (the earlier tries) was not enough on 410, where
/// the timer already runs and simply refuses to advance because -_isAutoScrollingBlocked
/// says so and -_shouldAutoScrollToObject: returns NO. Those two are the ones that
/// were missing. Every gate is now driven to the value that means "yes, advance",
/// each behind a guard so a build without it is skipped, never handed a dead method.
///
/// Gate names came from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3), which
/// ships one build per Instagram version; here a single build carries them all and
/// the guard picks. The mechanism is Albrhi's own.
///
/// No on-screen button — toggled from Reels settings — so the reels action bar and
/// its download button stay where Instagram puts them.
///

static BOOL SCIWantsAutoScroll(void) {
    return [SCIUtils getBoolPref:@"reels_auto_next"];
}

// MARK: - Argument-less gates

// A gate is a zero-argument BOOL getter. Each is driven to a fixed value while the
// feature is on — YES for an "enabled/should" gate, NO for a "blocked/disabled" one
// — and left to answer for itself when off, so nothing changes with the toggle down.
#define SCI_MAX_GATES 12
static struct { Class cls; SEL selector; IMP original; BOOL forced; } sGates[SCI_MAX_GATES];
static size_t sGateCount = 0;

static BOOL SCIGateTrampoline(id self, SEL _cmd) {
    for (size_t i = 0; i < sGateCount; i++) {
        if (sGates[i].selector == _cmd && [self isKindOfClass:sGates[i].cls]) {
            if (SCIWantsAutoScroll()) return sGates[i].forced;
            return sGates[i].original ? ((BOOL (*)(id, SEL))sGates[i].original)(self, _cmd) : NO;
        }
    }
    return NO;
}

static void SCIForceGate(Class cls, NSString *name, BOOL forced) {
    if (!cls || sGateCount >= SCI_MAX_GATES) return;

    SEL selector = NSSelectorFromString(name);
    if (!selector || !class_getInstanceMethod(cls, selector)) return;

    IMP original = NULL;
    MSHookMessageEx(cls, selector, (IMP)SCIGateTrampoline, &original);
    if (!original) return;

    sGates[sGateCount].cls = cls;
    sGates[sGateCount].selector = selector;
    sGates[sGateCount].original = original;
    sGates[sGateCount].forced = forced;
    sGateCount++;
}

// MARK: - The two-argument decision gate

// -_shouldAutoScrollToObject:exclusionRule: is where 410 finally decides. It takes
// arguments, so it needs its own trampoline: the generic one would drop them and
// corrupt the passthrough while the feature is off.
static BOOL (*orig_shouldAutoScrollToObject)(id, SEL, id, NSUInteger);
static BOOL sci_shouldAutoScrollToObject(id self, SEL _cmd, id object, NSUInteger rule) {
    if (SCIWantsAutoScroll()) return YES;
    return orig_shouldAutoScrollToObject ? orig_shouldAutoScrollToObject(self, _cmd, object, rule) : NO;
}

%ctor {
    @autoreleasepool {
        Class feed = objc_getClass("IGSundialFeedViewController");
        Class engine = objc_getClass("_TtC19IGSundialAutoScroll19IGSundialAutoScroll");

        // Enabled/should gates → YES.
        SCIForceGate(feed, @"isAutoAdvanceEnabled", YES);
        SCIForceGate(feed, @"autoAdvanceToNextItem", YES);
        SCIForceGate(feed, @"autoScrollState", YES);                // 410
        SCIForceGate(feed, @"_shouldAutoScrollAfterSwipeBack", YES); // 410
        SCIForceGate(engine, @"shouldForceEnableAutoScroll", YES);  // 439
        SCIForceGate(engine, @"isAutoAdvanceEnabled", YES);

        // Blocked/disabled gates → NO.
        SCIForceGate(feed, @"_isAutoScrollingBlocked", NO);         // 410
        SCIForceGate(feed, @"advanceToNextItemDisabled", NO);       // 439

        // The two-argument decision, where present.
        SEL decision = NSSelectorFromString(@"_shouldAutoScrollToObject:exclusionRule:");
        if (feed && class_getInstanceMethod(feed, decision)) {
            MSHookMessageEx(feed, decision,
                            (IMP)sci_shouldAutoScrollToObject,
                            (IMP *)&orig_shouldAutoScrollToObject);
        }

        SCILogV(@"[Albrhi] reels auto-scroll gates forced: %zu", sGateCount);
    }
}

// MARK: - On-screen toggle

// An optional button that turns auto-scroll on and off without a trip to settings.
//
// It is a floating overlay on the reels view controller — pinned to the trailing
// edge with constraints — not a member of Instagram's action bar. An earlier try
// added it into the sidebar, where it fought the download button's own layout hook
// for the same bar and, on a build whose bar is a different class, never appeared at
// all. Sitting on the view controller sidesteps both: it always shows, holds its
// place as reels scroll underneath, and never touches the action bar.

static const NSInteger SCIAutoScrollButtonTag = 0x5CA57;

static void SCIStyleAutoScrollButton(UIButton *button) {
    BOOL on = SCIWantsAutoScroll();
    NSString *glyph = on ? @"infinity.circle.fill" : @"infinity.circle";

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:glyph withConfiguration:config] forState:UIControlStateNormal];

    button.tintColor = on ? [SCIUtils SCIColor_Primary] : [UIColor whiteColor];
    button.accessibilityLabel = SCILocalized(@"p_reels_autonext_t");
}

%hook IGSundialFeedViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![SCIUtils getBoolPref:@"reels_autoscroll_button"]) {
        [[self.view viewWithTag:SCIAutoScrollButtonTag] removeFromSuperview];
        return;
    }
    if ([self.view viewWithTag:SCIAutoScrollButtonTag]) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SCIAutoScrollButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // A dark disc so the glyph stays legible over any reel.
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    button.layer.cornerRadius = 17.0;

    SCIStyleAutoScrollButton(button);
    [button addTarget:self action:@selector(sciToggleAutoScroll:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    // Upper-right, below the camera row and well above the like button at the top of
    // the action stack — the earlier centre placement landed right on the like.
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-14.0],
        [button.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:104.0],
        [button.widthAnchor constraintEqualToConstant:34.0],
        [button.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

%new - (void)sciToggleAutoScroll:(UIButton *)sender {
    BOOL next = !SCIWantsAutoScroll();
    [[NSUserDefaults standardUserDefaults] setBool:next forKey:@"reels_auto_next"];

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    SCIStyleAutoScrollButton(sender);

    [SCIUtils showToastForDuration:1.6
                             title:SCILocalized(next ? @"reels_autonext_on" : @"reels_autonext_off")];
}

%end

// MARK: - Duration-aware drive from the progress indicator

// Forcing the gates does not start the older build's auto-scroll timer, and the
// countdown callback that would have fed it is itself gated off. The progress
// indicator is not: it updates continuously as the reel plays, on both builds, so it
// is the one reliable "the reel is ending" signal. When progress reaches the end the
// feed controller is told to advance, once per play — Instagram's own advance, so the
// transition is the native one.

// The feed controller this cell belongs to, found up the responder chain.
static UIViewController *SCIFeedControllerForView(UIView *view) {
    Class feed = objc_getClass("IGSundialFeedViewController");
    UIResponder *responder = view;
    while ((responder = responder.nextResponder)) {
        if (feed && [responder isKindOfClass:feed]) return (UIViewController *)responder;
    }
    return nil;
}

// One "already advanced this play" flag per cell, cleared when the reel loops back to
// the start, so each play triggers exactly one advance.
static const void *SCIReelAdvancedKey = &SCIReelAdvancedKey;

%hook IGSundialViewerVideoCell

- (void)updateProgressIndicatorWithProgress:(double)progress
                          remainingDuration:(double)remaining
                            elapsedDuration:(double)elapsed
                              totalDuration:(double)total {
    %orig;

    if (!SCIWantsAutoScroll()) return;

    // Back at the start of a loop: arm for the next end.
    if (progress < 0.5) {
        objc_setAssociatedObject(self, SCIReelAdvancedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    // A real, played-through clip near its end, and not already handled this loop.
    // The total guards against zero-length or still-loading items firing instantly.
    if (progress < 0.985 || total < 0.3) return;
    if (objc_getAssociatedObject(self, SCIReelAdvancedKey)) return;

    objc_setAssociatedObject(self, SCIReelAdvancedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIViewController *feed = SCIFeedControllerForView(self);
    if (!feed) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!SCIWantsAutoScroll()) return;

        // The auto-scroll advance where it exists (the older build), else the plain
        // next-item advance. Both are Instagram's own.
        if ([feed respondsToSelector:@selector(advanceToNextReelForAutoScroll)]) {
            ((void (*)(id, SEL))objc_msgSend)(feed, @selector(advanceToNextReelForAutoScroll));
        } else if ([feed respondsToSelector:@selector(advanceToNextItemWithNavigationAction:)]) {
            ((void (*)(id, SEL, NSInteger))objc_msgSend)(feed, @selector(advanceToNextItemWithNavigationAction:), 0);
        }
    });
}

%end
