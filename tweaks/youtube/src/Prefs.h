#import <Foundation/Foundation.h>

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that
/// silently never turns on: nothing checks that the key a hook reads is the key the
/// settings screen writes. Here they are constants, so a mistake is a compile error.
///
#define SCIPrefHideAds          @"hide_ads"
#define SCIPrefBackgroundPlay   @"background_playback"
#define SCIPrefHidePaidPromo    @"hide_paid_promotion"
#define SCIPrefBlockUpdateNag   @"block_update_nag"
#define SCIPrefVerboseLogging   @"verbose_logging"

/// Downloads.
///
/// `SCIPrefAutoPhotos` defaults to **off**, and that is the change 0.13.0 is about: a
/// download used to go to Photos and nowhere else, which meant the tweak decided where
/// someone's video lived. Now it stays in the Download Centre and going to Photos is a
/// swipe, or this switch for anyone who wants the old ending back.
#define SCIPrefAutoPhotos       @"auto_save_photos"
#define SCIPrefTabButton        @"tab_download_button"

/// A save button in the Shorts action bar, beside like and share.
///
/// On by default, unlike most additions: Shorts has no long press to spare, so without this
/// there is no way at all to save one, and a feature nobody can reach is not a choice.
#define SCIPrefShortsButton     @"shorts_download_button"

/// Writing the cover into the sound file itself.
///
/// **Off, and that is a retreat.** It shipped on in 0.22.0 and rewrote every saved song to
/// tag it -- unverified -- and left a library that would not play. 0.23.0 stopped it
/// producing broken files, but the trade was already wrong: what it buys is a picture when
/// a song is sent to someone else, and what it risks is the song. Anything that replaces a
/// file the user cannot get back again has to be asked for.
#define SCIPrefEmbedArtwork     @"embed_artwork"

/// Removing a save from the Centre once it has reached Photos.
///
/// Off. Photos is where a video goes to be kept and the Centre is where it goes to be
/// played, and deciding for someone that they wanted only one of those is not this tweak's
/// call -- particularly when the removal cannot be undone.
#define SCIPrefTidyAfterPhotos  @"tidy_after_photos"

/// A notification when a save finishes while you are elsewhere.
///
/// On. Transfers now continue with the app closed, so the moment a download ends is a moment
/// nobody is watching -- and a result delivered to an empty room is not a result.
#define SCIPrefFinishNotice     @"finish_notice"

/// Which pair of buttons the lock screen gets.
///
/// Off means next and previous, which is the default because a queue you cannot move
/// through is not a queue. iOS shows one pair or the other and never both, so this is a
/// choice and not two switches.
#define SCIPrefLockScreenSkip   @"lock_screen_skip"

/// Quality.
///
/// The two caps are resolutions, not menu positions -- 1080 means 1080, and 0 means leave
/// it alone. A stored index would be a number whose meaning lives in whatever order the
/// picker happened to list things in, and reordering the list would silently change
/// everyone's setting.
#define SCIPrefClassicQuality   @"classic_quality_menu"
#define SCIPrefCapWiFi          @"quality_cap_wifi"
#define SCIPrefCapCellular      @"quality_cap_cellular"


/// How far a double tap jumps, in seconds. Zero means leave YouTube's own ten alone.
///
/// A number and not an index, for the reason the quality caps are: 30 means thirty seconds
/// whatever order the picker happens to list things in.
#define SCIPrefSeekSeconds      @"seek_seconds"

/// Rates past 2× in the speed menu. Off — the menu is YouTube's and lengthening it is a
/// change to a screen nobody asked us to touch.
#define SCIPrefExtraSpeeds      @"extra_speeds"

/// Asking the player not to use SABR.
///
/// **Off, and it stays off until a report says the gates are even consulted.** SABR is the
/// piecewise protocol that leaves every format without a URL; this asks YouTube's own two
/// switches to decline it. Whether the server honours the request is not knowable from here,
/// and forcing it could as easily cost playback as gain a download link — so with this off
/// the hooks only count, and the diagnostics page reports what they counted.
#define SCIPrefBypassSABR       @"bypass_sabr"

/// Parts of YouTube's own screen that can be answered away. All off: removing pieces of
/// somebody else's app is a choice, and choosing it for everyone is not this tweak's call.
#define SCIPrefHideAmbient      @"hide_ambient_glow"
#define SCIPrefHideEndscreen    @"hide_endscreen"
#define SCIPrefHideInfoCards    @"hide_info_cards"
#define SCIPrefHideNotifyButton @"hide_notify_button"
#define SCIPrefHideCreateButton @"hide_create_button"
#define SCIPrefHideCastButton   @"hide_cast_button"
#define SCIPrefHideSearchButton @"hide_search_button"
#define SCIPrefHideSharePromo   @"hide_share_promo"


/// SponsorBlock. One key for the feature, one per category.
///
/// Per-category rather than a single switch, because these are not the same request of
/// the video: skipping a paid advertisement is not the same decision as skipping the
/// creator's own intro, and a user who wants one may well not want the other.
#define SCIPrefSponsorBlock     @"sponsorblock"
#define SCIPrefSBNotice         @"sponsorblock_notice"
#define SCIPrefSBMarkers        @"sponsorblock_markers"

#define SCIPrefSBSponsor        @"sb_sponsor"
#define SCIPrefSBSelfPromo      @"sb_selfpromo"
#define SCIPrefSBInteraction    @"sb_interaction"
#define SCIPrefSBIntro          @"sb_intro"
#define SCIPrefSBOutro          @"sb_outro"
#define SCIPrefSBPreview        @"sb_preview"
#define SCIPrefSBFiller         @"sb_filler"
#define SCIPrefSBMusicOffTopic  @"sb_music_offtopic"

/// Read on every hook call, so it has to be cheap.
///
/// NSUserDefaults caches in memory after the first read, and these hooks run on the
/// main thread during layout and playback where a lock would show. Instagram's side of
/// this repository memoises the same call behind a lock because it has 227 call sites;
/// this has a handful, and measuring before adding that machinery is the rule here.
static inline BOOL SCIPrefEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// For the settings that are a number rather than a switch. Absent reads as 0, which is
/// what every one of them uses to mean "do nothing".
static inline NSInteger SCIPrefNumber(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}
