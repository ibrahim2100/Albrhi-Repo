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
/// Both new references were read for where their own visible download button actually
/// lives, cross-validated between them: NA9 For TikTok hooks `AWEFeedViewTemplateCell`
/// (a `%new` method, `na9AddDownloadButton`, called from `-layoutSubviews`) *and*, on
/// the newer rail, `TTKFeedInteractionStackView` / `TTKFeedRightInteractionStackView`
/// (`na9SidebarDownloadButtonTapped:`, `-layoutSubviews`, `-didMoveToWindow`) — the
/// vertical stack of like/comment/bookmark/share icons beside the video. VibeTok, a
/// download-free tweak, independently hooks `TTKFeedInteractionStackView
/// -layoutSubviews` too, for its own unrelated reason, which is a second confirmation
/// that class is real and live rather than an NA9-only surface.
///
/// Both `TTKFeedInteractionStackView` and `TTKFeedRightInteractionStackView` are
/// confirmed present as literal strings in TikTok 46.4.0's own `MusicallyCore`
/// binary — read directly, the same no-`otool` method this project uses everywhere —
/// so both are hooked, the same "either name can attach, a %hook on an absent class
/// never does" reasoning the X tweak's own immersive button already uses for its two
/// rail names.
///
/// **What is not carried over from either reference is how the button finds out what
/// to download.** Both call a `na9...`-prefixed method that presumably reads a model
/// property this project has not independently confirmed exists on the stack view
/// itself. Rather than guess at that accessor, the model is caught at a point that is
/// already confirmed beyond doubt: `AWEFeedViewTemplateCell -configWithModel:` and
/// `-configureWithModel:` are two of NA9's own hooked selectors, and a hooked method's
/// own argument needs no confirmation at all -- it is simply what was passed. The
/// resolved URL is stashed on the cell itself the moment its model is set, and the
/// button -- nested somewhere inside that cell -- reads it back by walking up its own
/// superview chain, the same upward search the X tweak's immersive button already
/// uses to reach `ImmersiveCardView` from its own rail.
///

@interface AWEFeedViewTemplateCell : UIView
@end

@interface TTKFeedInteractionStackView : UIStackView
@end

@interface TTKFeedRightInteractionStackView : UIStackView
@end

static const NSInteger kSCIButtonTag = 0x5C17;
static const void *kSCIItemKey = &kSCIItemKey;

static BOOL sciCellHooked = NO;
static BOOL sciRailPresent = NO;
static NSString *sciRailName = nil;
static NSUInteger sciButtonsPlaced = 0;

/// The superview chain above the rail, recorded once if nothing is ever found there --
/// the same "name what was actually walked" idea the X tweak's own immersive button
/// report uses, so a future TikTok update that moves the rail again says so instead of
/// leaving "0 buttons" to mean four different things.
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


/// Reads what `-configWithModel:`/`-configureWithModel:` stashed, walking up from the
/// rail to whichever ancestor is the cell.
static SCITTMediaItem *SCITTItemAboveView(UIView *view) {
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        SCITTMediaItem *item = objc_getAssociatedObject(ancestor, kSCIItemKey);
        if (item) return item;
    }
    return nil;
}

/// Puts the button on a rail, or refreshes the one already there. One function for two
/// classes, called from each hook's own -layoutSubviews with self -- the same reasoning
/// the X tweak's own SCITWPlaceImmersiveButton function gives for not writing this twice.
static void SCITTPlaceButton(UIStackView *stack) {
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
            SCILogV(@"in-feed button: nothing resolved above it — %@", sciNoItemChain);
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
    if (SCIPrefEnabled(SCIPrefDownloadButton) && [model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
        NSURL *url = [SCITTMedia resolveURLForModel:model];
        if (url) {
            SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
            item.url = url;
            item.seen = [NSDate date];
            objc_setAssociatedObject(self, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            objc_setAssociatedObject(self, kSCIItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

- (void)configureWithModel:(id)model {
    %orig;
    if (SCIPrefEnabled(SCIPrefDownloadButton) && [model isKindOfClass:NSClassFromString(@"AWEAwemeModel")]) {
        NSURL *url = [SCITTMedia resolveURLForModel:model];
        if (url) {
            SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
            item.url = url;
            item.seen = [NSDate date];
            objc_setAssociatedObject(self, kSCIItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            objc_setAssociatedObject(self, kSCIItemKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

%end

%end


%group RailA

%hook TTKFeedInteractionStackView

- (void)layoutSubviews {
    %orig;
    SCITTPlaceButton(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITTPlaceButton(self);
}

%end

%end


%group RailB

%hook TTKFeedRightInteractionStackView

- (void)layoutSubviews {
    %orig;
    SCITTPlaceButton(self);
}

- (void)didMoveToWindow {
    %orig;
    SCITTPlaceButton(self);
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
        SCILogV(@"neither interaction rail is in this build — no in-feed button");
    }
}

NSString *SCITTButtonReport(void) {
    if (!sciCellHooked) return @"AWEFeedViewTemplateCell not in this build";
    if (!sciRailPresent) return @"cell hooked, no interaction rail in this build";
    if (sciButtonsPlaced == 0 && sciNoItemChain) {
        return [NSString stringWithFormat:@"%@ — 0 buttons placed; above it: %@",
                sciRailName, sciNoItemChain];
    }
    return [NSString stringWithFormat:@"%@ — %lu button(s) placed",
            sciRailName ?: @"?", (unsigned long)sciButtonsPlaced];
}
