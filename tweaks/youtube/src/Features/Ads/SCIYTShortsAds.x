#import <UIKit/UIKit.h>
#import "../../SCILog.h"
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
/// The ad itself, at the layer that draws it.
///
/// Refusing the ad page controller was not enough: a Shorts advertisement came through
/// anyway and reported itself, again with FLEX, as
///
///   <ELMContainerNode: eml.ad_image>  frame (0 137; 390 488)
///
/// -- most of the screen. So the page is built regardless of what its controller answers,
/// and the picture is drawn by an Elements node inside it. That is the layer to refuse at,
/// and it is the same layer the Home feed's `eml.feed_ad_metadata` lives on.
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

%hook ELMContainerNode

- (void)didEnterVisibleState {
    %orig;

    if (!SCIPrefEnabled(SCIPrefHideAds)) return;

    NSString *text = nil;
    @try {
        text = [self description];
    } @catch (__unused NSException *exception) {
        return;
    }
    if (!text.length) return;

    for (NSString *identifier in SCIAdNodeIdentifiers()) {
        if (![text containsString:identifier]) continue;

        // Hidden and made transparent, not resized. A node's size belongs to the layout that
        // placed it, and fighting that from here is how a feed ends up with overlapping rows;
        // an invisible node still occupies its space, which is a gap rather than an ad.
        ((ELMContainerNode *)self).hidden = YES;
        ((ELMContainerNode *)self).alpha = 0;

        [SCIYTDiagnostics recordShortsAd:
            [NSString stringWithFormat:@"hid a node matching %@", identifier]];
        SCILogV(@"ads: hid an ELM node matching %@", identifier);
        return;
    }
}

%end
