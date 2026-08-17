#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTButton.h"
#import "SCITTMedia.h"
#import "SCITTDownload.h"
#import "../../TikTokHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// A button in the feed itself, beside like/comment/share -- and only one at a time.
///
/// **Both surfaces attached and placed real buttons** (a device report showed a cell
/// overlay placing 3 and the interaction rail placing 9), which proved the classes and
/// the hook points right. What it also showed was 4-6 buttons on screen scattered
/// across it at once -- because TikTok keeps more than one cell alive at a time for
/// smooth scrolling (the current one and its prefetched neighbours), and this file was
/// showing a button on *every* alive cell's own rail rather than only the one actually
/// on screen. Reported directly, and it is a real bug independent of anything about
/// class names.
///
/// **The cell-overlay surface is dropped.** It was the fallback for a build where the
/// rail turned out not to exist; this device's own report already proved the rail does,
/// so carrying a second surface only doubled the scatter for no benefit. One surface,
/// arranged in the rail beside TikTok's own icons -- which is also what was asked for.
///
/// **Visibility is now restricted to whichever rail is actually centred in its own
/// window.** Every alive cell's rail still runs `-layoutSubviews`, but only the one
/// whose vertical centre sits within a quarter of the screen's height of the window's
/// own centre shows its button; every other alive rail hides its own. Comparing centres
/// in window coordinates costs nothing TikTok's view hierarchy does not already have
/// (`-convertRect:toView:`) and needs no knowledge of which cell TikTok itself
/// considers "current."
///

@interface TTKFeedInteractionStackView : UIStackView
@end

@interface TTKFeedRightInteractionStackView : UIStackView
@end

static const NSInteger kSCIRailButtonTag = 0x5C17;
static const void *kSCIItemKey = &kSCIItemKey;

static BOOL sciRailPresent = NO;
static NSString *sciRailName = nil;
static NSUInteger sciRailButtonsPlaced = 0;


@interface SCITTButtonTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
@end

@implementation SCITTButtonTarget

+ (instancetype)shared {
    static SCITTButtonTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITTButtonTarget alloc] init]; });
    return shared;
}

- (void)tapped:(UIButton *)button {
    SCITTMediaItem *item = objc_getAssociatedObject(button, kSCIItemKey);
    if (!item) {
        SCILogV(@"in-feed download button: nothing captured yet");
        return;
    }
    [SCITTDownload save:item];
}

@end


/// Whether `view` is the one actually on screen right now, among however many of
/// TikTok's own cells happen to be alive at once. A quarter of the window's own height
/// is generous enough to survive the button's own position inside the rail (it is not
/// pinned to the rail's exact centre) without also lighting up a neighbour cell that is
/// only barely, momentarily visible during a fast scroll.
static BOOL SCITTViewIsCentered(UIView *view) {
    UIWindow *window = view.window;
    if (!window || window.bounds.size.height <= 0) return NO;

    CGRect frameInWindow = [view convertRect:view.bounds toView:window];
    CGFloat viewCenterY = CGRectGetMidY(frameInWindow);
    CGFloat windowCenterY = CGRectGetMidY(window.bounds);

    return fabs(viewCenterY - windowCenterY) < (window.bounds.size.height * 0.25);
}

static void SCITTPlaceRailButton(UIStackView *stack) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    UIButton *existing = (UIButton *)[stack viewWithTag:kSCIRailButtonTag];

    if (!SCITTViewIsCentered(stack)) {
        existing.hidden = YES;
        return;
    }

    SCITTMediaItem *item = [SCITTMedia recent].firstObject;

    if (existing) {
        existing.hidden = (item == nil);
        if (item) objc_setAssociatedObject(existing, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (!item) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kSCIRailButtonTag;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:26
                                                        weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:config]
            forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];

    // **The width constraint v0.4.10 added is what made this worse, not better.** A
    // vertical UIStackView whose alignment is `fill` -- the default, and what TikTok's
    // own rail evidently uses, since its icons span the rail's whole width -- gives
    // every arranged subview the stack's full width. Pinning this one to 34 points
    // fought that: the constraint and the fill cannot both hold, and the loser shows
    // as a button sitting off to one side of a column whose other icons are centred in
    // their own full-width slots. Only the height is constrained now; the width is
    // left to the stack, and the glyph is centred inside whatever width that turns out
    // to be -- which is precisely how every sibling icon in the rail already behaves.
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    [button.heightAnchor constraintEqualToConstant:34].active = YES;

    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Second from the end, not appended after everything. TikTok's own rail is
    // avatar, like, comment, bookmark, share, then a spinning record/music-disc icon
    // last -- a layout this project has not confirmed against a class dump the way
    // every hook target elsewhere in this tweak is, but is consistent and well known
    // across TikTok's own app regardless of build. Appending at the very end landed
    // the button after that disc rather than under share, which is what was reported.
    // Inserting one position before the end puts it directly under share on that
    // layout; if a future build's rail does not end with the disc, this simply lands
    // one icon higher than intended rather than breaking anything.
    NSUInteger count = stack.arrangedSubviews.count;
    NSUInteger index = count > 0 ? count - 1 : 0;

    if ([stack respondsToSelector:@selector(insertArrangedSubview:atIndex:)]) {
        [stack insertArrangedSubview:button atIndex:index];
    } else if ([stack respondsToSelector:@selector(addArrangedSubview:)]) {
        [stack addArrangedSubview:button];
    } else {
        [stack addSubview:button];
    }

    sciRailButtonsPlaced++;
}


%group RailA

%hook TTKFeedInteractionStackView

- (void)layoutSubviews {
    %orig;
    SCITTPlaceRailButton(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITTPlaceRailButton(self);
}

%end

%end


%group RailB

%hook TTKFeedRightInteractionStackView

- (void)layoutSubviews {
    %orig;
    SCITTPlaceRailButton(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITTPlaceRailButton(self);
}

%end

%end


void SCITTInstallButton(void) {
    if (NSClassFromString(@"TTKFeedInteractionStackView")) {
        %init(RailA);
        sciRailPresent = YES;
        sciRailName = @"TTKFeedInteractionStackView";
    }
    if (NSClassFromString(@"TTKFeedRightInteractionStackView")) {
        %init(RailB);
        sciRailPresent = YES;
        sciRailName = sciRailName
            ? [sciRailName stringByAppendingString:@" + TTKFeedRightInteractionStackView"]
            : @"TTKFeedRightInteractionStackView";
    }

    if (sciRailPresent) {
        SCILogV(@"in-feed button: attached to %@", sciRailName);
    } else {
        SCILogV(@"neither interaction rail is in this build — no in-feed button");
    }
}

NSString *SCITTButtonReport(void) {
    if (!sciRailPresent) return @"no interaction rail in this build";
    return [NSString stringWithFormat:@"%@ — %lu placed",
        sciRailName ?: @"?", (unsigned long)sciRailButtonsPlaced];
}
