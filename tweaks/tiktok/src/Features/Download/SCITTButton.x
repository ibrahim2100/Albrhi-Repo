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
static BOOL sciPlacedAfterShare = NO;


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
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = kSCIRailButtonTag;
    [button.heightAnchor constraintEqualToConstant:44].active = YES;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:27
                                                        weight:UIImageSymbolWeightSemibold];
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:config]];
    glyph.tintColor = [UIColor whiteColor];
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    // The glyph must never intercept the tap meant for the button under it.
    glyph.userInteractionEnabled = NO;
    [button addSubview:glyph];

    [NSLayoutConstraint activateConstraints:@[
        [glyph.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
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
    // **Placed by finding share, not by counting from the end.** "Second from last"
    // assumed TikTok's rail ends with its spinning music disc -- an assumption about a
    // layout this project has never actually read, and the button landed in the wrong
    // place twice on the strength of it. The siblings' own class names are right here
    // to be searched instead: TikTok names its rail icons for what they do, so the one
    // whose class name mentions share is the one to sit under. Recorded for the report
    // either way, so a build whose naming does not match says so instead of silently
    // landing somewhere odd.
    //
    NSArray<UIView *> *siblings = stack.arrangedSubviews;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NSInteger shareIndex = -1;

    for (NSUInteger i = 0; i < siblings.count; i++) {
        NSString *name = NSStringFromClass([siblings[i] class]);
        [names addObject:name];
        if (shareIndex < 0 && [name.lowercaseString containsString:@"share"]) {
            shareIndex = (NSInteger)i;
        }
    }
    sciRailContents = [names componentsJoinedByString:@" | "];

    if ([stack respondsToSelector:@selector(insertArrangedSubview:atIndex:)]) {
        // Directly after share where it was found; otherwise at the very end, which is
        // at least a predictable place rather than an arithmetic guess at one.
        NSUInteger index = (shareIndex >= 0)
            ? (NSUInteger)(shareIndex + 1)
            : siblings.count;
        [stack insertArrangedSubview:button atIndex:MIN(index, siblings.count)];
        sciPlacedAfterShare = (shareIndex >= 0);
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

    NSMutableString *out = [NSMutableString stringWithFormat:@"%@ — %lu placed",
        sciRailName ?: @"?", (unsigned long)sciRailButtonsPlaced];

    [out appendFormat:@"; %@", sciPlacedAfterShare
        ? @"after share" : @"share not found, appended at end"];

    if (sciRailContents) [out appendFormat:@"; rail: %@", sciRailContents];

    return out;
}
