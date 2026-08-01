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
