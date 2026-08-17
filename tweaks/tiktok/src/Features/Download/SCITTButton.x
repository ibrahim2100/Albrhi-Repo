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
/// **Primary surface: a button drawn directly on the cell, the same shape NA9 For
/// TikTok's own `AWEFeedViewTemplateCell -layoutSubviews` → `na9AddDownloadButton`
/// mechanism uses** — its own author reports this exact surface working, unmodified,
/// across several years of TikTok updates, which is a stronger confirmation than a
/// string in a binary: it is what a real, long-running device actually renders. The
/// cell itself is confirmed present in TikTok 46.4.0's own binary; positioning a
/// button on it needs no other class to exist at all, unlike the sidebar surface below.
///
/// **Secondary surface: the interaction rail**, `TTKFeedInteractionStackView` /
/// `TTKFeedRightInteractionStackView`, which NA9 also hooks (`na9SidebarDownloadButtonTapped:`)
/// as a second, newer button style, and which VibeTok independently touches for an
/// unrelated reason. Kept as an extra surface in case a given build renders through it
/// even where the cell overlay does not, the same "keep both, a %hook on an absent class
/// never attaches" reasoning the X tweak's own immersive button already uses for two
/// rail names.
///
/// Both surfaces read the same association, stashed on the cell the moment
/// `-configWithModel:`/`-configureWithModel:` sets its model — two of NA9's own hooked
/// selectors, so the argument itself needs no further confirmation.
///

@interface AWEFeedViewTemplateCell : UIView
@end

@interface TTKFeedInteractionStackView : UIStackView
@end

@interface TTKFeedRightInteractionStackView : UIStackView
@end

static const NSInteger kSCIButtonTag = 0x5C17;
static const NSInteger kSCICellButtonTag = 0x5C18;
static const void *kSCIItemKey = &kSCIItemKey;

static BOOL sciCellHooked = NO;
static BOOL sciRailPresent = NO;
static NSString *sciRailName = nil;
static NSUInteger sciButtonsPlaced = 0;
static NSUInteger sciCellButtonsPlaced = 0;

static NSString *sciNoItemChain = nil;


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
        SCILogV(@"in-feed download button: nothing resolved for this cell yet");
        return;
    }
    [SCITTDownload save:item];
}

@end


/// Reads what `-configWithModel:`/`-configureWithModel:` stashed, walking up from any
/// descendant view to whichever ancestor is the cell.
static SCITTMediaItem *SCITTItemAboveView(UIView *view) {
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        SCITTMediaItem *item = objc_getAssociatedObject(ancestor, kSCIItemKey);
        if (item) return item;
    }
    return nil;
}

/// The primary surface: a round button drawn straight onto the cell, bottom-right,
/// clear of the safe area. `self` in the caller is the cell itself, so the item is its
/// own association -- no walk needed, the same shortcut the X tweak's own
/// `ImmersiveCardView` surface takes for the identical reason ("no walk: the card
/// answers -status, so it is its own model").
static void SCITTPlaceCellButton(UIView *cell) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    SCITTMediaItem *item = objc_getAssociatedObject(cell, kSCIItemKey);

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

    // Bottom-right, clear of TikTok's own interaction rail (which sits in the same
    // corner, stacked upward) by a wide vertical margin -- 140pt clears a five-icon
    // rail with room to spare rather than guessing at its exact height.
    CGFloat side = 46.0;
    CGFloat inset = 14.0;
    CGFloat aboveBottom = 140.0;
    CGRect bounds = cell.bounds;
    button.frame = CGRectMake(bounds.size.width - side - inset,
                               bounds.size.height - aboveBottom,
                               side, side);

    // Done every pass: TikTok's own overlays (caption, progress bar, rail) are added
    // and re-added as the cell is configured, and a button under one of them is a
    // button nobody can tap -- the same reason the X tweak's own card surface raises
    // its button on every -layoutSubviews rather than once.
    [cell bringSubviewToFront:button];
}

/// The secondary surface: an arranged subview of the interaction rail, refreshed the
/// same way the X tweak's own SCITWPlaceImmersiveButton refreshes its rail button.
static void SCITTPlaceRailButton(UIStackView *stack) {
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;

    UIButton *existing = (UIButton *)[stack viewWithTag:kSCIButtonTag];
    SCITTMediaItem *item = SCITTItemAboveView(stack);

    if (existing) {
        existing.hidden = (item == nil);
        if (item) objc_setAssociatedObject(existing, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (!item) {
        if (!sciNoItemChain) {
            NSMutableArray<NSString *> *chain = [NSMutableArray array];
            for (UIView *ancestor = stack; ancestor && chain.count < 10; ancestor = ancestor.superview) {
                [chain addObject:NSStringFromClass([ancestor class])];
            }
            sciNoItemChain = [chain componentsJoinedByString:@" < "];
            SCILogV(@"in-feed button: nothing resolved above the rail — %@", sciNoItemChain);
        }
        return;
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kSCIButtonTag;

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

    sciButtonsPlaced++;
}


%group Cell

%hook AWEFeedViewTemplateCell

- (void)configWithModel:(id)model {
    %orig;
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;
    if (![model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) return;

    NSURL *url = [SCITTMedia resolveURLForModel:model];
    if (url) {
        SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
        item.url = url;
        item.seen = [NSDate date];
        objc_setAssociatedObject(self, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(self, kSCIItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    SCITTPlaceCellButton(self);
}

- (void)configureWithModel:(id)model {
    %orig;
    if (!SCIPrefEnabled(SCIPrefDownloadButton)) return;
    if (![model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) return;

    NSURL *url = [SCITTMedia resolveURLForModel:model];
    if (url) {
        SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
        item.url = url;
        item.seen = [NSDate date];
        objc_setAssociatedObject(self, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(self, kSCIItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    SCITTPlaceCellButton(self);
}

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
    if (NSClassFromString(@"AWEFeedViewTemplateCell")) {
        %init(Cell);
        sciCellHooked = YES;
        SCILogV(@"in-feed button: bound to AWEFeedViewTemplateCell's own model");
    } else {
        SCILogV(@"AWEFeedViewTemplateCell is not in this build — no in-feed button");
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
    if (!sciCellHooked) return @"AWEFeedViewTemplateCell not in this build";

    NSMutableString *out = [NSMutableString stringWithFormat:
        @"cell overlay — %lu placed", (unsigned long)sciCellButtonsPlaced];

    if (!sciRailPresent) {
        [out appendString:@"; no interaction rail in this build"];
    } else if (sciButtonsPlaced == 0 && sciNoItemChain) {
        [out appendFormat:@"; %@ — 0 placed; above it: %@", sciRailName, sciNoItemChain];
    } else {
        [out appendFormat:@"; %@ — %lu placed", sciRailName ?: @"?", (unsigned long)sciButtonsPlaced];
    }

    return out;
}
