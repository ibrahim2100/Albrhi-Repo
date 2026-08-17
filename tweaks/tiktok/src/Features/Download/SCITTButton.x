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

/// What the rail actually contained when the button was placed, and whether share was
/// found in it -- so a build whose icon naming does not match says so rather than
/// silently landing the button somewhere odd.
static NSString *sciRailContents = nil;
static BOOL sciPlacedBeforeLast = NO;


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

    //
    // **A plain image button was tried three ways and read tilted every time.** Set as
    // the button's own image, `UIButton` positions it through `contentEdgeInsets`,
    // `contentHorizontalAlignment` and its own `imageView` frame -- all of which
    // iOS 15+ reinterprets through `UIButtonConfiguration` whether one was asked for
    // or not, and none of which this project can confirm against TikTok's own rail
    // metrics. Pinning a fixed width made it worse (it fought the stack's own fill
    // alignment); leaving the width free was still off-centre.
    //
    // So the glyph is no longer the button's image at all. It is a separate
    // `UIImageView` centred inside the button by two constraints of this file's own
    // making -- `centerXAnchor` and `centerYAnchor` -- which nothing in `UIButton`'s
    // internal layout or in the stack's alignment can reinterpret. The button itself
    // keeps no intrinsic content, so the stack sizes it purely from the height
    // constraint below and whatever width the fill gives it, and the glyph sits in the
    // middle of that by construction rather than by any alignment property holding.
    //
    // The height is constrained further down, from a sibling's own measured height
    // rather than a number chosen here -- see the placement block.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = kSCIRailButtonTag;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:27
                                                        weight:UIImageSymbolWeightSemibold];
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:config]];
    glyph.tintColor = [UIColor whiteColor];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    // The glyph must never intercept the tap meant for the button under it.
    glyph.userInteractionEnabled = NO;
    [button addSubview:glyph];

    //
    // **Centre constraints alone are what left it looking off to one side.** A button
    // whose glyph is a *subview* rather than its own image has no intrinsic content
    // size at all -- so in a stack whose alignment is not `fill`, it is laid out at
    // zero width, and a glyph centred on a zero-width button hangs off the edge of it.
    // That is the tilt, and it survived three attempts because every one of them
    // adjusted the centring rather than the sizing.
    //
    // Pinning the glyph to all four edges instead gives the button a real intrinsic
    // size -- the image's own -- so it measures correctly under any alignment, and
    // `UIViewContentModeCenter` keeps the artwork unstretched inside whatever the stack
    // then grants it.
    //
    glyph.contentMode = UIViewContentModeCenter;
    [NSLayoutConstraint activateConstraints:@[
        [glyph.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [glyph.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [glyph.topAnchor constraintEqualToAnchor:button.topAnchor],
        [glyph.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
    ]];

    // Same shadow TikTok's own white glyphs carry over bright video, so the button
    // stays visible on a pale frame rather than disappearing into it.
    glyph.layer.shadowColor = [UIColor blackColor].CGColor;
    glyph.layer.shadowOpacity = 0.35;
    glyph.layer.shadowRadius = 3;
    glyph.layer.shadowOffset = CGSizeZero;

    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    //
    // **Searching the siblings for "share" cannot work, and a device report is what
    // proved it.** The rail's arranged subviews came back as:
    //
    //   TTKRightInteractionAreaBackgroundView | PlayInteractionLikeView |
    //   TTKRightInteractionAreaBackgroundView ×4
    //
    // TikTok wraps every icon except like in the *same* generically-named background
    // view, so no icon but like can be identified by class name at all. The name search
    // therefore always failed and always fell through to appending at the very end --
    // below the music disc, which is what "way below the picture" was describing. That
    // was a regression this file introduced; the index arithmetic it replaced was
    // closer to right.
    //
    // So: one position before the end. On the six-item rail above that is between the
    // fifth wrapper and the sixth, which is where the button belongs on TikTok's own
    // avatar/like/comment/bookmark/share/disc order. It is still an assumption about
    // that order -- but it is now a *recorded* one, printed in the report beside the
    // rail's real contents, rather than one buried in code.
    //
    NSArray<UIView *> *siblings = stack.arrangedSubviews;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (UIView *sibling in siblings) {
        [names addObject:NSStringFromClass([sibling class])];
    }
    sciRailContents = [names componentsJoinedByString:@" | "];

    // Matched to a sibling's own height rather than a number picked here, so the button
    // occupies the same vertical slot every other icon does instead of whatever 44
    // points happens to look like on this rail.
    // Width as well as height, and this is what "leaning far to the right" was.
    //
    // Only the height was matched. A vertical stack whose alignment is not .fill positions
    // each arranged subview by its own width, so a button sized from its glyph sat at a
    // different horizontal offset from every icon around it -- pushed off to one side by
    // however much narrower or wider than them it happened to be. Nothing about the index
    // could fix that; it is a sizing bug, and the report calling the placement "nice but
    // leaning right" is precisely the shape of one.
    //
    // Both dimensions come from a sibling rather than from numbers chosen here, so the button
    // occupies the same slot TikTok's own icons do on whatever rail it lands in.
    UIView *reference = siblings.lastObject;
    CGFloat side = (reference && reference.bounds.size.height > 8)
        ? reference.bounds.size.height : 44;
    CGFloat wide = (reference && reference.bounds.size.width > 8)
        ? reference.bounds.size.width : side;

    [button.heightAnchor constraintEqualToConstant:side].active = YES;
    [button.widthAnchor constraintEqualToConstant:wide].active = YES;

    // And centred inside whatever width it is given, so the glyph sits on the same vertical
    // line as the icons above and below rather than against one edge of its own box.
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;

    // Beside a real interaction view, not "one before last".
    //
    // A device report dumped what this rail actually holds, and most of it is not buttons:
    //
    //   TTKRightInteractionAreaBackgroundView | TikTokFeedInteractionBiz.PlayInteractionLikeView
    //   | TTKRightInteractionAreaBackgroundView x4
    //
    // The interactive elements are `PlayInteraction*` views (Swift, module
    // TikTokFeedInteractionBiz); the rest are background containers. Inserting before the
    // last item therefore dropped the button between two backgrounds -- which is exactly the
    // "not centred, not aligned with the icons" that was reported, and no amount of sizing
    // would have fixed it, because the neighbours it was being sized against are not icons.
    //
    // So the anchor is the *last* view whose class names an interaction, and the button goes
    // straight after it. Matched on the name rather than the class object because these are
    // Swift types in a submodule -- the mangled name is not something to hardcode when the
    // substring is unambiguous and already in the report.
    NSInteger anchor = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)siblings.count; i++) {
        NSString *cls = NSStringFromClass([siblings[(NSUInteger)i] class]);
        if ([cls containsString:@"PlayInteraction"] || [cls containsString:@"InteractionButton"]) {
            anchor = i;
        }
    }

    if (anchor != NSNotFound && [stack respondsToSelector:@selector(insertArrangedSubview:atIndex:)]) {
        [stack insertArrangedSubview:button atIndex:(NSUInteger)(anchor + 1)];
    } else if (siblings.count >= 2 && [stack respondsToSelector:@selector(insertArrangedSubview:atIndex:)]) {
        // No interaction view found: keep the old behaviour rather than inventing a new one.
        [stack insertArrangedSubview:button atIndex:siblings.count - 1];
        sciPlacedBeforeLast = YES;
    } else if ([stack respondsToSelector:@selector(addArrangedSubview:)]) {
        [stack addArrangedSubview:button];
    } else {
        [stack addSubview:button];
    }

    sciRailButtonsPlaced++;
}


///
/// **`-setHidden:` and `-setAlpha:` are hooked because NA9 hooks them, and reading why
/// explained the last remaining complaint.** Those two are in its own symbol table
/// alongside `-layoutSubviews` and `-didMoveToWindow` for both rails — and a tweak has
/// no reason to hook them unless its button's visibility has to be *kept in step with
/// the rail's own*. TikTok hides and fades this rail constantly: while a comment sheet
/// is open, during a long-press, on a live cell, whenever the UI gets out of the video's
/// way. A button that does not follow those transitions is a button that is sometimes
/// there and sometimes not for no reason the user can see — which is precisely the
/// "doesn't show on every video" report, arriving from the app's own behaviour rather
/// than from any failure to place it.
///
/// Placement itself stays where it is: an arranged subview of the rail, so the stack
/// lays it out. What these two add is the rail's own hidden/alpha state being applied to
/// the button on every change, so it appears and fades exactly when its neighbours do.
///
static void SCITTSyncRailButton(UIStackView *stack) {
    UIButton *button = (UIButton *)[stack viewWithTag:kSCIRailButtonTag];
    if (!button) return;

    // Never *shown* by this -- placement decides that, and only for the centred cell.
    // This only ever propagates the rail going away or fading.
    if (stack.isHidden || stack.alpha < 0.99) {
        button.hidden = stack.isHidden;
        button.alpha = stack.alpha;
    } else if (SCITTViewIsCentered(stack)) {
        button.alpha = 1.0;
    }
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

- (void)setHidden:(BOOL)hidden {
    %orig;
    SCITTSyncRailButton(self);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    SCITTSyncRailButton(self);
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

- (void)setHidden:(BOOL)hidden {
    %orig;
    SCITTSyncRailButton(self);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    SCITTSyncRailButton(self);
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

    NSMutableString *out = [NSMutableString stringWithFormat:@"%@ — %lu placed",
        sciRailName ?: @"?", (unsigned long)sciRailButtonsPlaced];

    [out appendFormat:@"; %@", sciPlacedBeforeLast
        ? @"one before last" : @"appended at end"];

    if (sciRailContents) [out appendFormat:@"; rail: %@", sciRailContents];

    return out;
}
