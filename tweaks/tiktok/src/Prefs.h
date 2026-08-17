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
