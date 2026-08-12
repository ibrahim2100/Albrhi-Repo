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

static const NSInteger kImmersiveButtonTag = 0x5C1E;
static const void *kImmersiveItemKey = &kImmersiveItemKey;

static BOOL sciImmersivePresent = NO;
static BOOL sciImmersiveHooked = NO;
static NSUInteger sciImmersiveButtons = 0;


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


%group Immersive

%hook _TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView

- (void)layoutSubviews {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    // Once. A recycled stack arrives with its button already in the arranged list, found by
    // tag, and its saved item refreshed rather than a second button added.
    UIButton *existing = (UIButton *)[self viewWithTag:kImmersiveButtonTag];

    // What is playing, searched for upward from here. The stack's own view answers nothing;
    // the card two steps up does.
    SCITWMediaItem *item = nil;
    for (UIView *view = self; view && !item; view = view.superview) {
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
    if ([self respondsToSelector:@selector(addArrangedSubview:)]) {
        [self addArrangedSubview:button];
    } else {
        [self addSubview:button];
    }

    sciImmersiveButtons++;
}

%end

%end


NSString *SCITWImmersiveButtonReport(void) {
    if (!sciImmersivePresent) return @"immersive player stack not in this build";
    if (!sciImmersiveHooked) return @"immersive stack found, hook not installed";
    return [NSString stringWithFormat:@"%lu buttons added", (unsigned long)sciImmersiveButtons];
}

void SCITWInstallImmersiveButton(void) {
    sciImmersivePresent =
        (NSClassFromString(@"_TtC14T1TwitterSwift39ImmersiveInlinePlaybackButtonsStackView") != nil);

    if (!sciImmersivePresent) {
        SCILogV(@"immersive player button stack not in this build");
        return;
    }

    %init(Immersive);
    sciImmersiveHooked = YES;
    SCILogV(@"immersive save button attached");
}
