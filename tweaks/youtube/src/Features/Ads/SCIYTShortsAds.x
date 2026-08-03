#import <UIKit/UIKit.h>
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

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
