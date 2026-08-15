#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITWImmersiveButton.h"
#import "SCITWStatusButton.h"   // SCITWFirstSaveableInStatusView
#import "SCITWMedia.h"
#import "SCITWDownload.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// The button, in the immersive player's control stack.
///
/// `ImmersiveInlinePlaybackButtonsStackView` is a Swift class, so it is bound by its mangled
/// runtime name -- `_TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView` -- through
/// a `%group` that is `%init`ed only when `objc_getClass` finds it by that exact name. A
/// search over the class list would be the wrong tool here for the reason the Instagram
/// reels button cost twice: inside a constructor it does not find what the exact name still
/// finds.
///
/// The button is added as an **arranged subview** of the stack, not a floating one. That is
/// the whole difference from the surface that never appeared: a UIStackView positions its
/// arranged subviews itself, so the button sits in the rail beside like and share with no
/// frame set and no layout fought. TWIGalaxy adds its there for exactly this reason.
///

@interface _TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView : UIStackView
@end

///
/// The same rail under the name X gives it now.
///
/// The button did not appear inside the video, and a class dump of com.atebits.Tweetie2
/// said why in one line: **`ImmersiveInlinePlaybackButtonsStackView` is not in this build
/// at all.** Its sibling `ImmersiveCardView` is (`T1TwitterSwift.ImmersiveCardView`), so
/// the dump does carry Swift classes and the absence is real rather than an artefact of
/// how it was taken.
///
/// X rebuilt the immersive player around plugin views — `ImmersiveEngagementActionsPluginView`,
/// `ImmersivePlayPauseButtonPluginView`, `ImmersiveTopRightActionsPluginsView` and some
/// thirty more — and the rail of action buttons is now `ImmersiveActionsStackView`, whose
/// members are `ImmersiveActionButton` (it carries `-didTapInlineActionButton:`). It is the
/// same shape as the old one: `-layoutSubviews`, `-hitTest:withEvent:`, `-initWithFrame:`,
/// a stack of buttons. Only the name moved.
///
/// **Both are kept, and this is deliberate.** TWIGalaxy's own binary still references the
/// old name, so builds carrying it exist; a `%hook` on an absent class never attaches, so
/// naming both costs nothing and means one X update cannot take the button away again
/// without the report saying which surface went. That is the same reasoning that keeps
/// three button surfaces alive in this tweak rather than one.
///
/// Bound by its mangled runtime name like its predecessor: `_TtC`, then the module's length
/// and name, then the class's. `ImmersiveActionsStackView` is 25 characters.
///
@interface _TtC14T1TwitterSwift25ImmersiveActionsStackView : UIStackView
@end

///
/// The page one video lives on, which is where a button that must stay *in* the video goes.
///
/// The action-bar button (SCITWActionBarButton.x) is on X's own row and is the reliable
/// one; it is not what was asked for. What was asked for is a button pinned inside the
/// picture that stays with that video while you swipe -- and that is a different surface
/// again, because the action row belongs to the screen, not to the clip.
///
/// `ImmersiveVideoPageView` is the per-video page in the immersive pager: one instance per
/// clip, carrying that clip's player. A subview added here is inside the video's own frame
/// and travels with it, because swiping moves the page. Confirmed in a class dump of this
/// build -- `-layoutSubviews`, `-initWithFrame:`, `-player:didUpdatePlaybackState:` -- and
/// bound by the mangled Swift name, `ImmersiveVideoPageView` being 22 characters.
///
/// It is *not* a stack view, so nothing rebuilds its children out from under us -- the
/// failure that made the rail add eleven invisible buttons. It is positioned by frame in
/// -layoutSubviews after %orig, and brought to the front each pass, because the immersive
/// player stacks full-screen plugin views over the video
/// (`ImmersiveProfileSwipePluginView` is 390x844 on this device) and a button underneath
/// one of those is a button nobody can tap.
///
@interface _TtC14T1TwitterSwift22ImmersiveVideoPageView : UIView
@end

///
/// The card itself — and this is the one TWIGalaxy uses.
///
/// Its package was read to settle this rather than reasoned about again. Every X class its
/// binary names is in `__cstring`, and of the immersive family there are exactly two:
/// `ImmersiveInlinePlaybackButtonsStackView`, which is not in X 12.15, and
/// **`ImmersiveCardView`, which is.** So the working in-video button in that tweak can only
/// be on the card.
///
/// It explains what three surfaces of ours could not. `ImmersiveCardView` is the *container*
/// for one video: `-playerView`, `-status`, `-playerSessionProducer`, `-handleSingleTap:`.
/// The plugin overlays are its children, so a button added to the card and raised sits above
/// them. `ImmersiveVideoPageView` sits underneath that stack — which is why 0.9.0 added seven
/// buttons and showed none, the same shape of failure as the rail's eleven.
///
/// It also answers `-status` directly, so there is no walk to do: the card is its own model,
/// which is the fix 0.7.1 already made to the shared lookup.
///
@interface _TtC14T1TwitterSwift17ImmersiveCardView : UIView
@end

static const NSInteger kImmersiveButtonTag = 0x5C1E;
static const void *kImmersiveItemKey = &kImmersiveItemKey;

static BOOL sciImmersivePresent = NO;
static BOOL sciImmersiveHooked = NO;
static NSUInteger sciImmersiveButtons = 0;

/// Which rail actually attached, for the report. Both can, so this is a name and not a flag.
static NSString *sciImmersiveRail = nil;

/// The superview chain above the rail, recorded the first time placement finds no media.
static NSString *sciImmersiveChain = nil;

/// The in-video button: its own tag and counter, so the report can tell the two apart.
static const NSInteger kInVideoButtonTag = 0x5C20;


/// The card surface, counted separately again — it can attach while the page does not.
static NSUInteger sciCardButtons = 0;
static BOOL sciCardHooked = NO;


@interface SCITWImmersiveButtonTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
@end

@implementation SCITWImmersiveButtonTarget

+ (instancetype)shared {
    static SCITWImmersiveButtonTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITWImmersiveButtonTarget alloc] init]; });
    return shared;
}

- (void)tapped:(UIButton *)button {
    SCITWMediaItem *item = objc_getAssociatedObject(button, kImmersiveItemKey);

    // Failing that, up the tree from the button. The stack's own ancestors reach
    // ImmersiveCardView, which is the one that knows what video is playing -- the same
    // upward search the status surface uses, reused rather than rewritten.
    for (UIView *view = button.superview; view && !item; view = view.superview) {
        item = SCITWFirstSaveableInStatusView(view);
    }

    if (!item) { SCILogV(@"immersive button: nothing saveable above it"); return; }
    [SCITWDownload save:item];
}

@end


/// Puts the button on a rail, or refreshes the one already there.
///
/// A plain function taking the stack, because two classes now need identical treatment and
/// the alternative is the same forty lines twice — which is how one of them ends up fixed
/// and the other not. It is called from each hook's `-layoutSubviews` with `self`.
static void SCITWPlaceImmersiveButton(UIStackView *stack) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    // Once. A recycled stack arrives with its button already in the arranged list, found by
    // tag, and its saved item refreshed rather than a second button added.
    UIButton *existing = (UIButton *)[stack viewWithTag:kImmersiveButtonTag];

    // What is playing, searched for upward from here. The stack's own view answers nothing;
    // the card two steps up does.
    SCITWMediaItem *item = nil;
    for (UIView *view = stack; view && !item; view = view.superview) {
        item = SCITWFirstSaveableInStatusView(view);
    }

    if (existing) {
        existing.hidden = (item == nil);
        if (item) objc_setAssociatedObject(existing, kImmersiveItemKey, item,
                                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (!item) {
        // What was actually walked, recorded once.
        //
        // "0 buttons added" has now cost two releases as a sentence that names a symptom and
        // no cause -- first the wrong class, then a class that answers -status rather than
        // -viewModel. The remaining unknown is whether the walk even passes ImmersiveCardView:
        // the immersive player is built of plugin views, and if the rail's plugin is a
        // *sibling* of the card rather than a descendant, no upward walk from here will ever
        // reach the model, and the fix is a different search rather than a different getter.
        //
        // The chain answers that in one line, so the next report settles it instead of another
        // round of reasoning about a hierarchy nobody here can see. Recorded once, not per
        // layout pass -- this runs continuously while a video plays.
        if (!sciImmersiveChain) {
            NSMutableArray<NSString *> *chain = [NSMutableArray array];
            for (UIView *view = stack; view && chain.count < 12; view = view.superview) {
                [chain addObject:NSStringFromClass([view class])];
            }
            sciImmersiveChain = [chain componentsJoinedByString:@" < "];
            SCILogV(@"immersive button: nothing saveable above it — %@", sciImmersiveChain);
        }
        return;
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kImmersiveButtonTag;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:22
                                                        weight:UIImageSymbolWeightRegular];
    [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"
                             withConfiguration:config]
            forState:UIControlStateNormal];

    // White, like the other controls in this player, which sit over video and are drawn
    // light for that reason. It joins a rail of X's own glyphs and matches them.
    button.tintColor = [UIColor whiteColor];

    [button addTarget:[SCITWImmersiveButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    objc_setAssociatedObject(button, kImmersiveItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Arranged, so the stack places it. Guarded because the class name says UIStackView and
    // the declaration assumes it, but a build that made it a plain view would otherwise get
    // a button at the origin -- addSubview is the honest fallback there.
    if ([stack respondsToSelector:@selector(addArrangedSubview:)]) {
        [stack addArrangedSubview:button];
    } else {
        [stack addSubview:button];
    }

    sciImmersiveButtons++;
}


%group Immersive

%hook _TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView

- (void)layoutSubviews {
    %orig;
    SCITWPlaceImmersiveButton(self);
}

%end

%end


%group ImmersiveActions

%hook _TtC14T1TwitterSwift25ImmersiveActionsStackView

- (void)layoutSubviews {
    %orig;
    SCITWPlaceImmersiveButton(self);
}

%end

%end


%group Card

%hook _TtC14T1TwitterSwift17ImmersiveCardView

- (void)layoutSubviews {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    @try {
        // No walk: the card answers -status, so it is its own model.
        SCITWMediaItem *item = SCITWFirstSaveableInStatusView(self);

        UIButton *button = (UIButton *)[self viewWithTag:kInVideoButtonTag];
        if (!item) { button.hidden = YES; return; }

        if (!button) {
            button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.tag = kInVideoButtonTag;

            UIImageSymbolConfiguration *config =
                [UIImageSymbolConfiguration configurationWithPointSize:26
                                                                weight:UIImageSymbolWeightSemibold];
            [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"
                                     withConfiguration:config]
                    forState:UIControlStateNormal];

            button.tintColor = [UIColor whiteColor];
            button.layer.shadowColor = [UIColor blackColor].CGColor;
            button.layer.shadowOpacity = 0.5;
            button.layer.shadowRadius = 3;
            button.layer.shadowOffset = CGSizeZero;

            [button addTarget:[SCITWImmersiveButtonTarget shared]
                       action:@selector(tapped:)
             forControlEvents:UIControlEventTouchUpInside];

            [self addSubview:button];
            sciCardButtons++;
        }

        button.hidden = NO;
        objc_setAssociatedObject(button, kImmersiveItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Below X's own back button, not beside it.
        //
        // The top-left corner is taken: X puts its back chevron there, and on a real device
        // the save button landed behind it -- reachable only when the chevron happened to be
        // hidden, which is what "the position is wrong while swiping" was describing.
        //
        // 72 points down clears a 44-point control and its inset with room to spare, and it
        // is measured from the safe area rather than the top of the view so it sits in the
        // same place on a device with a notch and one without.
        CGFloat side = 44.0;
        CGFloat inset = 16.0;
        CGFloat below = 72.0;
        button.frame = CGRectMake(inset, self.safeAreaInsets.top + inset + below, side, side);

        // The whole reason this surface works where the page did not: the plugin overlays
        // are this view's own children, so raising the button here puts it above them.
        // Done every pass, because more of them arrive as the video plays.
        [self bringSubviewToFront:button];
    } @catch (NSException *exception) {
        SCILogV(@"card button: %@", exception.reason);
    }
}

%end

%end




NSString *SCITWImmersiveButtonReport(void) {
    if (!sciImmersivePresent) {
        return @"neither immersive rail is in this build "
                "(ImmersiveActionsStackView, ImmersiveInlinePlaybackButtonsStackView)";
    }
    if (!sciImmersiveHooked) return @"immersive rail found, hook not installed";

    // Which one, by name. "No button" used to be two silent reasons at once, and after an X
    // update the useful question is not whether a button appeared but which rail is left.
    if (sciImmersiveButtons == 0 && sciImmersiveChain) {
        // The chain, not just the zero. Which classes sit above the rail is the one thing
        // that separates "wrong getter" from "the model is not up there at all".
        return [NSString stringWithFormat:@"%@ — 0 buttons added; above it: %@",
                sciImmersiveRail ?: @"?", sciImmersiveChain];
    }

    return [NSString stringWithFormat:@"%@ — %lu buttons added",
            sciImmersiveRail ?: @"?", (unsigned long)sciImmersiveButtons];
}

NSString *SCITWInVideoButtonReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    [parts addObject:sciCardHooked
        ? [NSString stringWithFormat:@"card %lu", (unsigned long)sciCardButtons]
        : @"card absent"];

    return [parts componentsJoinedByString:@", "];
}

void SCITWInstallImmersiveButton(void) {
    // The current name first, the older one after it. Both are tried and both can attach:
    // one build may carry either, and a %hook on an absent class never installs, so asking
    // for both costs nothing and survives X moving the rail again.
    if (NSClassFromString(@"_TtC14T1TwitterSwift25ImmersiveActionsStackView")) {
        %init(ImmersiveActions);
        sciImmersivePresent = YES;
        sciImmersiveHooked = YES;
        sciImmersiveRail = @"ImmersiveActionsStackView";
        SCILogV(@"immersive save button attached to ImmersiveActionsStackView");
    }

    if (NSClassFromString(@"_TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView")) {
        %init(Immersive);
        sciImmersivePresent = YES;
        sciImmersiveHooked = YES;
        sciImmersiveRail = sciImmersiveRail
            ? [sciImmersiveRail stringByAppendingString:@" + ImmersiveInlinePlaybackButtonsStackView"]
            : @"ImmersiveInlinePlaybackButtonsStackView";
        SCILogV(@"immersive save button attached to ImmersiveInlinePlaybackButtonsStackView");
    }

    if (!sciImmersivePresent) {
        SCILogV(@"no immersive button rail in this build");
    }

    // The in-video page is a separate surface with a separate answer: the rail can be
    // missing while this is present, and the report says so for each.
    // The card first: it is the surface TWIGalaxy uses, and the only immersive class in its
    // binary that exists on this build.
    if (NSClassFromString(@"_TtC14T1TwitterSwift17ImmersiveCardView")) {
        %init(Card);
        sciCardHooked = YES;
        SCILogV(@"save button attached to ImmersiveCardView");
    }


}
