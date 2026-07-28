#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Stops a watched story from being reported as seen.
///
/// This used to hook IGStorySeenStateUploader, returning nil from its init and from
/// -networker. Walking the class metadata of both tested Instagram binaries showed
/// why that never worked: the class has exactly three methods — an init, a networker
/// getter and .cxx_destruct — so it cannot upload anything itself. Whatever nil it
/// was handed, the receipt left by another route.
///
/// The receipt is carried by IGStorySeenState, built with dictionaries of what was
/// watched. Both builds declare it identically — same seven-argument init, same
/// ivars — so emptying the seen dictionaries as it is constructed blocks the report
/// at a place every route has to pass through, on either version.
///
/// The skipped dictionaries are left alone: skipping past a story is not the same
/// claim as having watched it, and blanking everything would make the object useless
/// rather than merely silent.
///
/// The class was identified from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3),
/// which references it in both of its per-version builds; the code here is Albrhi's.
///

/// Set by the eye button in StorySeenButton.x. While true the receipt is let
/// through, so the story currently being watched registers as seen.
extern BOOL storySeenOverrideEnabled;

/// Whether the seen receipt should be blocked right now.
static BOOL SCIShouldBlockSeenReceipt(void) {
    if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;

    return !storySeenOverrideEnabled;
}

%hook IGStorySeenState

- (id)initWithReelSeenDictionary:(id)reelSeen
              liveSeenDictionary:(id)liveSeen
           reelSkippedDictionary:(id)reelSkipped
           liveSkippedDictionary:(id)liveSkipped
                 containerModule:(id)containerModule
                    pushCategory:(id)pushCategory
                    forceSeenIds:(id)forceSeenIds {

    if (!SCIShouldBlockSeenReceipt()) {
        return %orig;
    }

    [SCIDiagnostics recordStorySeenIntercept];
    SCILogV(@"[Albrhi] Emptied a story seen report before it was sent");

    NSMutableDictionary *noReels = [NSMutableDictionary dictionary];
    NSMutableDictionary *noLive = [NSMutableDictionary dictionary];

    return %orig(noReels, noLive, reelSkipped, liveSkipped, containerModule, pushCategory, @[]);
}

%end
