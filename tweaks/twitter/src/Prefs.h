#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that
/// silently never turns on: nothing checks that the key a hook reads is the key the
/// settings screen writes. Here they are constants, so a mistake is a compile error.
///

/// Whether the switch layer is hooked at all.
///
/// On, because with it off this release does nothing whatsoever -- there is no second
/// feature to fall back to. It exists so that a build of X where the hook causes trouble
/// can be made ordinary again from the settings screen rather than by uninstalling.
#define SCIPrefSwitchLayer      @"switch_layer"

/// The user's own answers, key to boolean. Written by the settings screen and read once
/// at launch; the shape is a dictionary rather than one preference per key because the
/// key names come from X and there is no list of them to declare in advance.
#define SCIPrefOverrides        @"switch_overrides"

/// One preference per named feature, so each is a plain boolean somebody could set from
/// anywhere -- rather than a second dictionary that only this code knows how to read.
///
/// The identifier after the prefix is fixed for life. Renaming one turns that feature off
/// on every device that had it on, silently, which is the kind of change that arrives as
/// "the update broke it" three weeks later.
#define SCIPrefFeaturePrefix    @"feature_"

/// Hiding the real Promoted Tweet -- an ordinary status the server marks `-isPromoted`,
/// unrelated to every `ssp_ads_*` switch "Hide ads" already turns off.
///
/// **Off by default, and marked experimental on the settings screen.** Read from a real
/// class dump, never confirmed on a phone: the class names and the property exist, whether
/// X's home timeline actually routes a promoted status through them on 12.15 is the one
/// thing only a device can answer. Shipped to be tried, not shipped as fixed.
#define SCIPrefHidePromoted     @"hide_promoted_tweets"

/// There is deliberately no preference for the two-finger hold.
///
/// It is the only way into this tweak's own screen, and a switch that can make the only
/// way in disappear is a switch that strands people -- the panel in Settings offers "off
/// for this app" and nothing finer, so there would be nowhere to turn it back on from.
/// Two fingers held for two thirds of a second is rare enough in a scrolling app to not
/// need one.

/// The download button drawn on the video itself, in X's own media chrome.
///
/// On by default: it is the thing people ask for by name, and a download button that ships
/// off is a feature nobody finds. The list under the two-finger hold is the fallback for a
/// build where X has renamed the view this rides on -- so turning this off leaves saving
/// working, which is why it is safe to default on.
#define SCIPrefInlineButton     @"inline_download_button"

/// Also hides a promoted trend, on the same status view classes' sibling surface.
///
/// Shares the main switch above rather than getting its own: it is the exact same
/// discovery -- `-isPromoted` reachable from the server-populated model, this time on
/// `TwitterURT.PromotableTrend` instead of `TFNTwitterStatus` -- and a second on/off row
/// for "the same thing, somewhere else" is a settings screen asking to be misread as two
/// different features.
#define SCIPrefHidePromotedTrends @"hide_promoted_trends"

/// Asks before a repost goes out, the way this project already asks before a DM's seen
/// receipt or an Instagram like -- a mis-tap on Retweet is a mis-tap that reaches every
/// follower, and undoing it does not un-notify anyone who already saw it.
///
/// Off by default. X's own retweet button costs one tap already; this adds a second, and
/// that is a real cost to weigh against the mis-tap it prevents, not a free safety net --
/// so the choice is left to whoever actually wants it rather than assumed for everyone.
#define SCIPrefConfirmRepost     @"confirm_repost"

/// Whether the download button also offers to save a profile photo, from the profile
/// screen's own avatar-tap gesture.
#define SCIPrefSaveAvatar        @"save_avatar"

/// Hides "who to follow" cards wherever `T1UserRecommendationView` draws one.
///
/// **A blunt tool, and marked as one.** That view is confirmed real; where X uses it is
/// not -- a dedicated page someone opens on purpose looks identical, from this class
/// alone, to the same card appearing uninvited in a timeline, and this cannot tell the two
/// apart. Off by default until a report says whether that trade is worth it.
#define SCIPrefHideSuggested     @"hide_suggested_accounts"

#define SCIPrefVerboseLogging   @"verbose_logging"
