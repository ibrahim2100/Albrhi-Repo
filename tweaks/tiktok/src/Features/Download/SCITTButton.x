#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITTButton.h"
#import "SCITTMedia.h"
#import "SCITTDownload.h"
#import "../../TikTokHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// A button in the feed itself, not only a list on the status screen.
///
/// **A device report settled the class question outright.** `AWEFeedViewTemplateCell`
/// -- the class both NA9 and VibeTok's own symbol tables name, and the one this tweak
/// hooked through v0.4.2 -- never actually fires on this build: its bind method was
/// never called, which is why every placement attempt found nothing. The report's own
/// "0 placed; above it: …" chain named the real ancestry instead, walked live from the
/// interaction rail up to its actual table cell:
///
///   TTKFeedInteractionStackView < TTKFeedInteractionMainView <
///   TTKFeedInteractionRootView < UITableViewCellContentView <
///   **AWEFeedViewCell** < AWENewFeedTableView < … < AWEFeedSlidingScrollView
///
/// `AWEFeedViewCell` is in neither reference's own hook table -- this build has simply
/// moved past what either tweak was written against, the same "the app rebuilt around
/// a new name" situation this project's CLAUDE.md already documents for X's own
/// action rail. It is confirmed the only way that matters here: read directly off a
/// live view hierarchy on the device this tweak actually runs on.
///
/// **The fix drops per-cell precision rather than guess at another bind method.**
/// Nothing above named which selector actually sets `AWEFeedViewCell`'s model, and
/// guessing one the way `AWEFeedViewTemplateCell`'s was guessed is exactly what
/// produced this bug. `-layoutSubviews` needs no such guess -- it is inherited from
/// `UIView` and fires on any cell regardless of what TikTok calls its own bind method.
/// The button reads `SCITTMedia`'s own most-recently-resolved item instead of a
/// per-cell association, the same "download the newest capture" shortcut this
/// project's own Locket quick-save button already takes and for the same reason: the
/// ad filter's own diagnostics already confirm `SCITTMedia` is capturing real items
/// (154 seen, 6 dropped, on the report that found this bug), so the newest one is
/// almost always the video just watched.
///
/// Two surfaces, both reading the same source: a direct overlay on `AWEFeedViewCell`
/// (primary; needs only that one class, now confirmed live) and an arranged subview of
/// the interaction rail (secondary, kept because it does attach and run on this build
/// -- the report's own "0 placed" for it, rather than silence, is what proved that).
/// `AWEFeedViewTemplateCell` is hooked too, at zero cost if it never fires again: a
/// `%hook` on a class that exists but is never reached simply never runs.
///

@interface AWEFeedViewCell : UIView
@end

@interface AWEFeedViewTemplateCell : UIView
@end

@interface TTKFeedInteractionStackView : UIStackView
@end

@interface TTKFeedRightInteractionStackView : UIStackView
@end

static const NSInteger kSCIRailButtonTag = 0x5C17;
static const NSInteger kSCICellButtonTag = 0x5C18;
static const void *kSCIItemKey = &kSCIItemKey;

static BOOL sciCellHooked = NO;
static BOOL sciRailPresent = NO;
static NSString *sciRailName = nil;
static NSUInteger sciRailButtonsPlaced = 0;
static NSUInteger sciCellButtonsPlaced = 0;


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


/// The primary surface: a round button drawn straight onto the cell, bottom-right,
/// clear of the safe area. Shown whenever anything has been captured at all -- it does
/// not try to be the specific video this cell holds, only the newest one seen, the
/// same shortcut Locket's own quick-save button takes.
static void SCITTPlaceCellButton(UIView *cell) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    SCITTMediaItem *item = [SCITTMedia recent].firstObject;
    UIButton *button = (UIButton *)[cell viewWithTag:kSCICellButtonTag];

    if (!item) {
        button.hidden = YES;
        return;
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = kSCICellButtonTag;

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:24
                                                            weight:UIImageSymbolWeightSemibold];
        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:config]
                forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];
        button.layer.shadowColor = [UIColor blackColor].CGColor;
        button.layer.shadowOpacity = 0.5;
        button.layer.shadowRadius = 3;
        button.layer.shadowOffset = CGSizeZero;

        [button addTarget:[SCITTButtonTarget shared]
                   action:@selector(tapped:)
         forControlEvents:UIControlEventTouchUpInside];

        [cell addSubview:button];
        sciCellButtonsPlaced++;
    }

    button.hidden = NO;
    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Bottom-right, clear of TikTok's own interaction rail by a wide vertical margin
    // rather than a guess at its exact height.
    CGFloat side = 46.0;
    CGFloat inset = 14.0;
    CGFloat aboveBottom = 140.0;
    CGRect bounds = cell.bounds;
    button.frame = CGRectMake(bounds.size.width - side - inset,
                               bounds.size.height - aboveBottom,
                               side, side);

    [cell bringSubviewToFront:button];
}

/// The secondary surface: an arranged subview of the interaction rail.
static void SCITTPlaceRailButton(UIStackView *stack) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    SCITTMediaItem *item = [SCITTMedia recent].firstObject;
    UIButton *existing = (UIButton *)[stack viewWithTag:kSCIRailButtonTag];

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

    [button addTarget:[SCITTButtonTarget shared]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];

    objc_setAssociatedObject(button, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if ([stack respondsToSelector:@selector(addArrangedSubview:)]) {
        [stack addArrangedSubview:button];
    } else {
        [stack addSubview:button];
    }

    sciRailButtonsPlaced++;
}


%group Cell

%hook AWEFeedViewCell

- (void)layoutSubviews {
    %orig;
    SCITTPlaceCellButton(self);
}

%end

%hook AWEFeedViewTemplateCell

- (void)layoutSubviews {
    %orig;
    SCITTPlaceCellButton(self);
}

%end

%end


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
    BOOL anyCell = NO;

    if (NSClassFromString(@"AWEFeedViewCell") || NSClassFromString(@"AWEFeedViewTemplateCell")) {
        %init(Cell);
        anyCell = YES;
    }

    sciCellHooked = anyCell;
    if (anyCell) {
        SCILogV(@"in-feed button: cell overlay attached");
    } else {
        SCILogV(@"neither AWEFeedViewCell nor AWEFeedViewTemplateCell is in this build — no in-feed button");
        return;
    }

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

    if (!sciRailPresent) {
        SCILogV(@"neither interaction rail is in this build — cell surface only");
    }
}

NSString *SCITTButtonReport(void) {
    if (!sciCellHooked) return @"neither AWEFeedViewCell nor AWEFeedViewTemplateCell is in this build";

    NSMutableString *out = [NSMutableString stringWithFormat:
        @"cell overlay — %lu placed", (unsigned long)sciCellButtonsPlaced];

    if (!sciRailPresent) {
        [out appendString:@"; no interaction rail in this build"];
    } else {
        [out appendFormat:@"; %@ — %lu placed", sciRailName ?: @"?", (unsigned long)sciRailButtonsPlaced];
    }

    return out;
}
