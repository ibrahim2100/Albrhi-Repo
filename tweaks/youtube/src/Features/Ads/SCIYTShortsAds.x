#import <UIKit/UIKit.h>
#import "../../SCILog.h"
#import "../../SCIYTLaunchGuard.h"
#import "../../Prefs.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../../YouTubeHeaders.h"

///
/// Ads in Shorts.
///
/// Identified the same way the Home feed one finally was -- by pointing at it on a real
/// phone. It reported itself as YTShortsAdsPlayerViewController, which is a page controller
/// of its own: a Short that is an advertisement gets a different class from a Short that is
/// a video, and that is a far cleaner thing to act on than any name read out of the binary.
///
/// **One selector, and it is the class's own question.** -isReadyForAdsRendering is what
/// this controller is asked before its ad is drawn, so answering no is refusing at the gate
/// the class itself provides rather than at some point of our choosing.
///
/// The four -startRendering...WithELMRenderer:completionBlock: methods were the obvious
/// alternative and are deliberately left alone. Skipping them means not calling a completion
/// block whose signature is not knowable from the binary, and a completion that never fires
/// is how a feed stops advancing -- trading an advertisement for a Shorts tab that hangs.
///
/// **What this does and does not do.** It stops the advertisement being drawn. It does not
/// remove the slot: the page is still there and still swipes past. Removing it means
/// filtering the item list the Shorts feed is built from, which nothing here has measured
/// yet, and guessing at it is how the Home feed got emptied in 0.20.1.
///

%hook YTShortsAdsPlayerViewController

- (BOOL)isReadyForAdsRendering {
    if (!SCIPrefEnabled(SCIPrefHideAds)) return %orig;

    // Recorded, because "Shorts still has ads" has two completely different causes and the
    // same complaint covers both: this class never being built -- ads arriving some other
    // way entirely -- or it being built and drawing anyway despite the refusal. A report
    // saying nothing at all means the first.
    [SCIYTDiagnostics recordShortsAd:@"refused to render an ad page"];
    SCILogV(@"ads: refused a Shorts ad");
    return NO;
}

%end


///
/// The ad itself, at the view that draws it.
///
/// Refusing the ad page controller was not enough -- the page is built whatever its
/// controller answers -- and refusing the node was not either: the first attempt matched on
/// the node's -description and never fired once, with the ad still on screen and hidden = 0.
///
/// FLEX then showed the answer plainly. The view carries
///
///   accessibilityIdentifier = eml.ad_image
///
/// which is a string property on a UIView, and the same identifier turns up on Home as well
/// as in Shorts. Reading a property beats being right about how a private class formats its
/// description.
///
/// **Matched against a short list of identifiers read off a screen, never off the binary.**
/// Both entries were measured. This deliberately does not match on `ad` or `promoted` or
/// anything shaped like them: this runs on every node the app renders, and a loose match
/// here would blank real content everywhere at once -- the 0.20.1 failure with a far larger
/// blast radius.
///
static NSArray<NSString *> *SCIAdNodeIdentifiers(void) {
    static NSArray *identifiers = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        identifiers = @[
            @"eml.ad_image",
            @"eml.feed_ad_metadata",
        ];
    });
    return identifiers;
}

%hook _ASDisplayView

- (void)didMoveToWindow {
    %orig;

    //
    // **Nothing here until the app is running, and this is where a launch was dying.**
    //
    // `_ASDisplayView` is AsyncDisplayKit's own view class: YouTube's entire interface is built
    // out of it, so this method is not "a hook on an ad card" -- it is a hook on **every view the
    // app ever puts in a window**. During a launch that is thousands of calls before the first
    // frame, each one reading a preference and then asking a Texture view for a property.
    //
    // Asking is the expensive half. `accessibilityIdentifier` on a node-backed view is not a
    // field lookup; it can make the node materialise, which during startup means work scheduled
    // on top of the work the app is already doing to start. The trail from a device that would
    // not open shows exactly this shape: a preference read at +0.0s and then nothing at all for
    // the eight seconds until the guard gave up.
    //
    // Shorts ads cannot be on screen before the app is, so the moment costs nothing: this stands
    // aside for the launch and works exactly as before from the first moment the app is active.
    //
    if (!SCIYTAppIsActive() || SCIYTStoodDown()) return;

    SCIYTLaunchMark(@"shorts ads: _ASDisplayView didMoveToWindow");

    if (!SCIPrefEnabled(SCIPrefHideAds)) return;

    // The view's own accessibility identifier, not the node's description.
    //
    // FLEX reported an ad card on Home carrying `accessibilityIdentifier = eml.ad_image`
    // outright, which is a plain string property on a plain UIView. The previous attempt
    // parsed -description off the node and it never fired -- the ad was still on screen with
    // hidden = 0 -- so whatever that hook was reading, it was not this. One property is worth
    // more than a description that has to be right about a private class's formatting.
    UIView *view = (UIView *)self;
    NSString *identifier = view.accessibilityIdentifier;
    if (!identifier.length) return;

    for (NSString *known in SCIAdNodeIdentifiers()) {
        if (![identifier isEqualToString:known]) continue;

        // Exact, not contained. This runs on every AsyncDisplayKit view the app puts in a
        // window, which is most of what you see, so it is the one place in this tweak where
        // a loose match would blank the app rather than a feed.
        view.hidden = YES;

        [SCIYTDiagnostics recordShortsAd:
            [NSString stringWithFormat:@"hid a view identified as %@", known]];
        SCILogV(@"ads: hid a view identified as %@", known);
        return;
    }
}

%end
