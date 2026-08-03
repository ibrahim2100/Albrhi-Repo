#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCIYTDownload.h"
#import "SCIYTShortsButton.h"
#import "Center/SCIYTIcon.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../../YouTubeHeaders.h"

///
/// A save button in Shorts, in the column with like, comment and share.
///
/// The same idea as the Instagram side's inline button, and the same reasoning: a feature
/// reached by a gesture nobody knows about is a feature nobody uses. Shorts has no long
/// press to spare -- the whole surface is already a scrubber and a swipe -- so it gets a
/// button instead.
///
/// **The hook is -layoutActionBar, and nothing about where the button goes is written down
/// as a number.** The action bar is found by measuring the overlay's own subviews: the
/// narrow column standing against the trailing edge is the one, and our button is placed
/// just above it. A hard-coded offset works on the phone it was tuned on and is wrong on
/// every other size, and this project has no second phone to check against.
///
/// What was found goes into the diagnostics report either way, so "no button in Shorts" is
/// answerable without another release to find out.
///

static char kSCIShortsButton;

/// The clip each overlay is actually drawing.
///
/// **Not the "currently playing" id.** Shorts builds the next clip's overlay while you are
/// still watching this one, so whatever was announced last is routinely the one below --
/// which is exactly what got downloaded. The overlay is handed its own model when it is
/// built, and that model is the only thing that knows which clip this particular button
/// belongs to.
static char kSCIShortsModel;

/// The action bar, by shape rather than by class name.
///
/// Narrow, tall, and hard against the trailing edge -- that is what the like/comment/share
/// column is and what nothing else in the overlay is. Naming its class would be a guess of
/// exactly the kind that left nineteen dead hooks in the tweak this project measured.
static UIView *SCIFindActionBar(UIView *overlay) {
    UIView *best = nil;

    for (UIView *child in overlay.subviews) {
        CGRect frame = child.frame;
        if (child.hidden || frame.size.width <= 0 || frame.size.height <= 0) continue;

        BOOL narrow = frame.size.width < overlay.bounds.size.width * 0.30;
        BOOL tall = frame.size.height > overlay.bounds.size.height * 0.20;
        BOOL trailing = CGRectGetMidX(frame) > overlay.bounds.size.width * 0.65;
        if (!narrow || !tall || !trailing) continue;

        // The lowest one that fits, because the action bar sits below anything else sharing
        // that column.
        if (!best || CGRectGetMaxY(frame) > CGRectGetMaxY(best.frame)) best = child;
    }

    return best;
}

%hook YTReelWatchPlaybackOverlayView

- (instancetype)initWithFrame:(CGRect)frame
                    reelModel:(id)reelModel
             ghostViewManager:(id)ghostViewManager
              parentResponder:(id)parentResponder {
    id overlay = %orig;

    // Kept weakly: the overlay does not own its model and must not start.
    if (overlay && reelModel) {
        objc_setAssociatedObject(overlay, &kSCIShortsModel, reelModel,
                                 OBJC_ASSOCIATION_ASSIGN);
    }
    return overlay;
}

- (void)layoutActionBar {
    %orig;

    if (!SCIPrefEnabled(SCIPrefShortsButton)) return;

    UIView *overlay = (UIView *)self;
    if (overlay.bounds.size.width <= 0) return;

    UIView *bar = SCIFindActionBar(overlay);

    UIButton *button = objc_getAssociatedObject(self, &kSCIShortsButton);

    // Re-added when the overlay has cleared its subviews, which it does between clips.
    // Remembering the button and not checking it is still in the view is how it appears on
    // the first Short and never again.
    if (button && button.superview != overlay) {
        [overlay addSubview:button];
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setImage:[SCIYTIcon downloadMarkOfSize:30 filled:YES]
                forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];

        // The same shadow every icon in that column carries. Without it a white glyph
        // disappears into a pale video, which is half of what Shorts are.
        button.layer.shadowColor = [UIColor blackColor].CGColor;
        button.layer.shadowOpacity = 0.5;
        button.layer.shadowRadius = 3;
        button.layer.shadowOffset = CGSizeZero;

        [button addTarget:[SCIYTShortsSaver class]
                   action:@selector(saveFrom:)
         forControlEvents:UIControlEventTouchUpInside];

        [overlay addSubview:button];
        objc_setAssociatedObject(self, &kSCIShortsButton, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // The button carries its overlay so the tap can find the right model. Weak, because
        // the overlay already owns the button.
        objc_setAssociatedObject(button, &kSCIShortsModel, overlay, OBJC_ASSOCIATION_ASSIGN);

        [SCIYTDiagnostics recordShortsButton:
            bar ? @"added above the action bar" : @"added, no action bar found — placed by edge"];
    }

    // Frames, never constraints. The layout engine took this tweak down in 0.1.1 and again
    // in 0.1.3, and a rectangle placed under a rectangle needs no help from it -- especially
    // inside a -layoutSubviews that is already running.
    CGFloat side = 44;
    CGFloat inset = 12;

    // In the column when it was found, and against the trailing edge when it was not. 0.23.0
    // returned early instead, so a shape this did not recognise meant no button at all -- and
    // the report said so to nobody, because nobody opens a report for a button they were
    // never told to expect. A button roughly in the right place beats a correct refusal.
    CGFloat x = bar ? CGRectGetMidX(bar.frame) - side / 2
                    : overlay.bounds.size.width - side - inset;

    // Above the column, not below it. Below put it in among the caption and the channel
    // name, and low enough on some screens to be under the tab bar entirely.
    CGFloat y = bar ? CGRectGetMinY(bar.frame) - side - 8
                    : overlay.bounds.size.height * 0.42;

    // Kept on screen whichever way it was placed.
    CGFloat lowest = overlay.bounds.size.height - side - inset;
    button.frame = CGRectMake(x, MIN(MAX(y, inset), lowest), side, side);

    // Brought to the front each pass: the overlay re-adds its own views on layout and ours
    // would end up behind them.
    [overlay bringSubviewToFront:button];
}

%end


///
/// The target.
///
/// A class object rather than the overlay, so the button holds no strong reference to a view
/// Shorts recycles. Which clip to save comes from the button's own overlay instead -- see
/// kSCIShortsModel above for why the "currently playing" id is the wrong answer here.
///
@implementation SCIYTShortsSaver

+ (void)saveFrom:(UIButton *)button {
    UIView *overlay = objc_getAssociatedObject(button, &kSCIShortsModel);
    id model = overlay ? objc_getAssociatedObject(overlay, &kSCIShortsModel) : nil;

    NSString *videoID = nil;
    if ([model respondsToSelector:@selector(videoId)]) {
        videoID = ((YTReelModel *)model).videoId;
    }

    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) return;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    SCILogV(@"shorts: save %@ (announced was %@)", videoID, [SCIYTDiagnostics activeVideoID]);
    [SCIYTDiagnostics recordShortsButton:
        [NSString stringWithFormat:@"saving %@, announced %@",
            videoID ?: @"?", [SCIYTDiagnostics activeVideoID] ?: @"?"]];

    // The same sheet the long press opens on a normal video. One download path, which is the
    // rule this project has kept since the Instagram side had four of them.
    [SCIYTDownload presentFrom:top videoID:videoID];
}

@end
