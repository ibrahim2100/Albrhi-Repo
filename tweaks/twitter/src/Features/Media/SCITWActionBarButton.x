#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITWActionBarButton.h"
#import "SCITWStatusButton.h"   // SCITWFirstSaveableInStatusView
#import "SCITWMedia.h"
#import "SCITWDownload.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// The save button on X's own inline action bar — the row with reply, repost, like and
/// share.
///
/// **This replaces the reasoning behind all three earlier surfaces, and the correction is
/// worth stating plainly: "11 buttons added" was the symptom, not the success.** The
/// immersive rail is `ImmersiveActionsStackView`, a Swift `UIStackView` whose arranged
/// subviews are rebuilt by X's own code. Our button went in as an arranged subview, X's
/// next rebuild removed it, the next layout pass found no button by tag and added another —
/// eleven times over one session, none of them visible. A rising add-count with nothing on
/// screen is the signature of that, not evidence of anything working.
///
/// **TWIGalaxy does not use that rail at all**, which its binary settles: it names exactly
/// two immersive Swift classes, `ImmersiveCardView` and the long-gone
/// `ImmersiveInlinePlaybackButtonsStackView`, so its immersive path is as dead on X 12.15 as
/// ours was. What it actually hooks is this bar — `TTAStatusInlineShareButton`,
/// `…FavoriteButton`, `…RetweetButton`, `…BookmarkButton`, and a selector named
/// `eleventhButtonTapped:`, which is a tweak adding an eleventh button to a row of ten.
///
/// **And this bar is drawn over the video as well as under a timeline post**, which is why
/// one surface answers both places and why the button "inside the video" appears there at
/// all. Three surfaces were being maintained for a job that has one.
///
/// Why this one is sound where the rail was not:
///
///   - It is **not** a stack view. It positions its buttons itself, in
///     `-_t1_layoutInlineActionButtons`, so a subview we add is not swept away by an
///     arranged-subview rebuild. We place ours after `%orig` has placed X's.
///   - It answers `-viewModel` directly, so the media lookup that already works for the
///     other surfaces needs no new path.
///   - `-setViewModel:options:displayType:displayTextOptions:account:` is a real bind
///     point: it fires on first use and on every cell reuse alike. That is the same lesson
///     `-didMoveToWindow` cost this tweak once already — a recycled cell is never removed
///     from its window, so a window callback fires once per view and never again.
///   - X extends this row itself (`TTAStatusInlineGrokButton`, `…AnalyticsButton`,
///     `…DownvoteButton` are all in the class dump), so it is a surface designed to take
///     another button rather than one being forced.
///

@interface TTAStatusInlineActionsView : UIView
- (id)viewModel;
- (NSArray *)inlineActionButtons;
@end

static const NSInteger kActionBarButtonTag = 0x5C1F;
static const void *kActionBarItemKey = &kActionBarItemKey;

static BOOL sciActionBarPresent = NO;
static BOOL sciActionBarHooked = NO;
static NSUInteger sciActionBarButtons = 0;
static NSUInteger sciActionBarNoMedia = 0;


@interface SCITWActionBarTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
@end

@implementation SCITWActionBarTarget

+ (instancetype)shared {
    static SCITWActionBarTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITWActionBarTarget alloc] init]; });
    return shared;
}

- (void)tapped:(UIButton *)button {
    SCITWMediaItem *item = objc_getAssociatedObject(button, kActionBarItemKey);

    // Failing that, upward — the bar knows its own model, and above it the post does.
    for (UIView *view = button.superview; view && !item; view = view.superview) {
        item = SCITWFirstSaveableInStatusView(view);
    }

    if (!item) { SCILogV(@"action bar: nothing saveable"); return; }
    [SCITWDownload save:item];
}

@end


/// Adds or refreshes the button on one bar, and places it after X's own row.
static void SCITWPlaceActionBarButton(TTAStatusInlineActionsView *bar) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    SCITWMediaItem *item = SCITWFirstSaveableInStatusView(bar);

    UIButton *existing = (UIButton *)[bar viewWithTag:kActionBarButtonTag];

    // A post with nothing to save gets no button. Hidden rather than removed, because this
    // bar is reused for the next post and rebuilding the button each time is work for
    // nothing — and counted, so the report can say "the bar is there and the posts had no
    // media" rather than leaving that indistinguishable from a hook that never ran.
    if (!item) {
        if (existing) existing.hidden = YES;
        else sciActionBarNoMedia++;
        return;
    }

    UIButton *button = existing;

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = kActionBarButtonTag;

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:17
                                                            weight:UIImageSymbolWeightRegular];
        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle"
                                 withConfiguration:config]
                forState:UIControlStateNormal];

        // X's own inline buttons take their colour from the theme rather than being drawn
        // white, and this row appears on a white background as often as over video. Asking
        // for the label colour is what makes it legible in both places without this file
        // knowing which one it is in.
        button.tintColor = [UIColor labelColor];

        [button addTarget:[SCITWActionBarTarget shared]
                   action:@selector(tapped:)
         forControlEvents:UIControlEventTouchUpInside];

        [bar addSubview:button];
        sciActionBarButtons++;
    }

    button.hidden = NO;
    objc_setAssociatedObject(button, kActionBarItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Placed with a frame, after X has placed its own.
    //
    // Deliberately not a constraint: this bar lays its buttons out by hand, in its own
    // -_t1_layoutInlineActionButtons, and mixing a constraint into a manually laid-out view
    // is how the Instagram panel came down twice. The last of X's buttons is the anchor, and
    // if the row is somehow empty the trailing edge is, so there is no arrangement in which
    // this has nothing to measure against.
    CGFloat height = CGRectGetHeight(bar.bounds);
    if (height <= 0) return;

    CGFloat side = MIN(height, 24.0);
    CGFloat y = (height - side) / 2.0;
    CGFloat x = CGRectGetWidth(bar.bounds) - side;

    NSArray *buttons = [bar respondsToSelector:@selector(inlineActionButtons)]
        ? [bar inlineActionButtons] : nil;

    CGFloat rightmost = 0;
    for (id candidate in buttons) {
        if (![candidate isKindOfClass:[UIView class]]) continue;
        CGFloat edge = CGRectGetMaxX(((UIView *)candidate).frame);
        if (edge > rightmost) rightmost = edge;
    }

    if (rightmost > 0 && rightmost + side <= CGRectGetWidth(bar.bounds)) {
        x = rightmost + 12.0;
    }

    button.frame = CGRectMake(x, y, side, side);
    [bar bringSubviewToFront:button];
}


%group ActionBar

%hook TTAStatusInlineActionsView

- (void)layoutSubviews {
    %orig;

    @try {
        SCITWPlaceActionBarButton(self);
    } @catch (NSException *exception) {
        // A button is a convenience; the action bar is how people reply and repost. Anything
        // thrown here costs the button alone.
        SCILogV(@"action bar: %@", exception.reason);
    }
}

- (void)setViewModel:(id)viewModel
             options:(unsigned long long)options
         displayType:(long long)displayType
  displayTextOptions:(unsigned long long)displayTextOptions
             account:(id)account {
    %orig;

    // The bind point, not just the layout pass. A recycled bar arrives with a new post and
    // the button's saved item has to follow it -- refreshing only on layout would leave a
    // button that saves whatever the previous post held, which is a worse bug than no
    // button at all.
    @try {
        SCITWPlaceActionBarButton(self);
    } @catch (NSException *exception) {
        SCILogV(@"action bar: %@", exception.reason);
    }
}

%end

%end


NSString *SCITWActionBarButtonReport(void) {
    if (!sciActionBarPresent) return @"TTAStatusInlineActionsView is not in this build";
    if (!sciActionBarHooked) return @"action bar found, hook not installed";

    return [NSString stringWithFormat:@"%lu buttons added, %lu bars with no media",
            (unsigned long)sciActionBarButtons, (unsigned long)sciActionBarNoMedia];
}

void SCITWInstallActionBarButton(void) {
    sciActionBarPresent = (NSClassFromString(@"TTAStatusInlineActionsView") != nil);

    if (!sciActionBarPresent) {
        SCILogV(@"TTAStatusInlineActionsView is not in this build");
        return;
    }

    %init(ActionBar);
    sciActionBarHooked = YES;
    SCILogV(@"save button attached to the inline action bar");
}
