#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that silently
/// never turns on. Here they are constants, so a mistake is a compile error.
///

/// Drops a feed item the server itself marked as an ad, before it is ever built into a
/// cell. On by default: it is why someone installs this.
#define SCIPrefHideAds          @"hide_ads"

/// A download button in the feed itself, beside like/comment/share, rather than only a
/// list to come back to on the status screen.
#define SCIPrefDownloadButton   @"download_button"

/// Whether the anti-tamper / jailbreak-detection cluster runs. Answers TikTok's own
/// checks the way an unmodified phone would; touches nothing about payment.
#define SCIPrefBypass           @"bypass"

/// Three separate switches, not one -- a story's seen mark, a message's read receipt
/// and a profile view are three different things reported to three different places,
/// and turning one off should not silently touch the other two. Never touches what
/// shows on this device's own screen -- only what gets reported back.
#define SCIPrefPrivacyStory     @"privacy_story"
#define SCIPrefPrivacyMessages  @"privacy_messages"
#define SCIPrefPrivacyProfile   @"privacy_profile"

#define SCIPrefVerboseLogging   @"verbose_logging"

/// Albrhi Panel's per-app switch, asked first. Every feature here reads its setting
/// through this one function, so turning the app off in the panel stands all of them
/// down at once -- the hooks stay installed and answer %orig, which is the only stop
/// that cannot leave the app half-patched.
static inline BOOL SCIPrefEnabled(NSString *key) {
    if (!SCIPanelAllowsThisApp()) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// The playback progress bar, kept visible.
///
/// TikTok fades its own bar out a moment after a video starts and only brings it back while
/// you are scrubbing, so there is normally no way to see how far through a clip you are.
/// NA9 keeps it up by answering `-setHidden:` and `-setAlpha:` on
/// `AWEFeedPlayerBottomProgressBar`, which is the same shape of fix as this project's other
/// "answer the question rather than fight the view" hooks.
#define SCIPrefProgressBar      @"show_progress_bar"

/// Saving the pictures from a photo post, not just video.
///
/// A TikTok photo post carries `imagePostInfo` / `imageList` / `images`, each confirmed in
/// the app's own binary. The download button already knows which model it belongs to, so
/// this is about what it does with a model whose media is pictures.
#define SCIPrefPhotoDownload    @"photo_download"
