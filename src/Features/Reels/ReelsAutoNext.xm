#import <substrate.h>
#import <objc/runtime.h>
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

// An optional button on the reels sidebar that turns auto-scroll on and off without
// a trip to settings — the control the sidebar was missing. It sits above the inline
// download button (or above the top control when that button is off), and holds its
// place because it is positioned every layout pass, in the bar's own coordinates.

static const NSInteger SCIAutoScrollButtonTag = 0x5CA57;
// Must match SCIInlineDownloadButtonTag in InlineDownloadButton.xm — the download
// button this one stacks above.
static const NSInteger SCIInlineDownloadButtonTag = 0x5CD10;

static void SCIStyleAutoScrollButton(UIButton *button) {
    BOOL on = SCIWantsAutoScroll();
    NSString *glyph = on ? @"infinity.circle.fill" : @"infinity.circle";

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightRegular];
    [button setImage:[UIImage systemImageNamed:glyph withConfiguration:config] forState:UIControlStateNormal];

    button.tintColor = on ? [SCIUtils SCIColor_Primary] : [UIColor labelColor];
    button.accessibilityLabel = SCILocalized(@"p_reels_autonext_t");
}

// The topmost interactive control in the bar, used as the fallback anchor when the
// download button is not present.
static UIView *SCITopControlInBar(UIView *bar) {
    UIView *top = nil;
    for (UIView *sub in bar.subviews) {
        if (sub.tag == SCIAutoScrollButtonTag || sub.tag == SCIInlineDownloadButtonTag) continue;
        if (sub.hidden || sub.alpha < 0.01 || CGRectIsEmpty(sub.frame)) continue;
        if (!top || CGRectGetMinY(sub.frame) < CGRectGetMinY(top.frame)) top = sub;
    }
    return top;
}

%hook IGSundialViewerVerticalUFI

- (void)layoutSubviews {
    %orig;

    UIButton *button = (UIButton *)[self viewWithTag:SCIAutoScrollButtonTag];

    if (![SCIUtils getBoolPref:@"reels_autoscroll_button"]) {
        [button removeFromSuperview];
        return;
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = SCIAutoScrollButtonTag;
        [button addTarget:self action:@selector(sciToggleAutoScroll:) forControlEvents:UIControlEventTouchUpInside];
        self.clipsToBounds = NO;   // the button sits above the bar's own bounds
        [self addSubview:button];
    }

    // Prefer to stack above the download button; fall back to the top control.
    UIView *anchor = (UIView *)[self viewWithTag:SCIInlineDownloadButtonTag];
    if (!anchor || anchor.hidden) anchor = SCITopControlInBar(self);

    if (!anchor) { button.hidden = YES; return; }

    CGFloat side = MAX(MIN(CGRectGetHeight(anchor.frame), CGRectGetWidth(anchor.frame)), 22.0);
    CGFloat gap = 14.0;

    button.hidden = NO;
    button.frame = CGRectMake(CGRectGetMidX(anchor.frame) - side / 2.0,
                              CGRectGetMinY(anchor.frame) - side - gap,
                              side, side);
    SCIStyleAutoScrollButton(button);
    [self bringSubviewToFront:button];
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
