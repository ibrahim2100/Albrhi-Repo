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

static const NSInteger kImmersiveButtonTag = 0x5C1E;
static const void *kImmersiveItemKey = &kImmersiveItemKey;

static BOOL sciImmersivePresent = NO;
static BOOL sciImmersiveHooked = NO;
static NSUInteger sciImmersiveButtons = 0;

/// Which rail actually attached, for the report. Both can, so this is a name and not a flag.
static NSString *sciImmersiveRail = nil;


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

    if (!item) return;

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


NSString *SCITWImmersiveButtonReport(void) {
    if (!sciImmersivePresent) {
        return @"neither immersive rail is in this build "
                "(ImmersiveActionsStackView, ImmersiveInlinePlaybackButtonsStackView)";
    }
    if (!sciImmersiveHooked) return @"immersive rail found, hook not installed";

    // Which one, by name. "No button" used to be two silent reasons at once, and after an X
    // update the useful question is not whether a button appeared but which rail is left.
    return [NSString stringWithFormat:@"%@ — %lu buttons added",
            sciImmersiveRail ?: @"?", (unsigned long)sciImmersiveButtons];
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
}
