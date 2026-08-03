#import "YouTubeHeaders.h"
#import "Tweak.h"
#import "UI/SCIYTWelcome.h"
#import "SCILog.h"
#import "Prefs.h"
#import "Diagnostics/SCIYTDiagnostics.h"

NSString *SCIVersionString = @"v0.28.1";  // AlbrhiYT

///
/// Capture, so the diagnostics page has something true to report.
///
/// Two hooks rather than one, because they see different things and the difference
/// is the whole point:
///
///   the player response is what YouTube *offered* for this video
///   MLVideo's streaming data is what the player is *using*
///
/// If those ever disagree -- an offered quality that never becomes a stream in use --
/// the report shows both and the disagreement is visible instead of being averaged
/// into one misleading answer. Measuring each stage separately is the lesson the
/// Instagram quality picker cost three attempts to learn.
///

%hook YTPlayerOverlayWrapper

- (void)setPlayerResponse:(id)playerResponse {
    %orig;
    [SCIYTDiagnostics recordPlayerResponse:playerResponse];
}

%end


%hook MLVideo

// All three initialisers this class declares, not just the widest one.
//
// Which of them the player actually uses is not knowable from the binary, and
// hooking one would leave the streams section blank whenever a different one was
// taken -- a blank that looks identical to "the hook did not attach" and would cost
// a round trip on a device to tell apart. Three small hooks are cheaper than that
// ambiguity.
- (id)initWithVideoDetails:(id)videoDetails
             streamingData:(id)streamingData
       clickTrackingParams:(id)clickTrackingParams
              threedLayout:(id)threedLayout
            playerCaptions:(id)playerCaptions
           hasOfflineState:(BOOL)hasOfflineState
      playableInBackground:(BOOL)playableInBackground {
    id video = %orig;
    [SCIYTDiagnostics recordVideo:video];
    return video;
}

- (id)initWithVideoDetails:(id)videoDetails
             streamingData:(id)streamingData
              threedLayout:(id)threedLayout
            playerCaptions:(id)playerCaptions {
    id video = %orig;
    [SCIYTDiagnostics recordVideo:video];
    return video;
}

- (id)initWithVideoDetails:(id)videoDetails
             streamingData:(id)streamingData
              threedLayout:(id)threedLayout {
    id video = %orig;
    [SCIYTDiagnostics recordVideo:video];
    return video;
}

%end


%ctor {
    // Defaults registered rather than assumed: reading a key that was never written
    // returns NO, which happens to be right for verbose logging and would be wrong
    // for the next setting added here. Registering makes the intended default
    // explicit at the one place it can be seen.
    // Ad hiding and background playback default to on: they are why someone installs
    // this, and shipping them off would mean a tweak that appears to do nothing until
    // its settings are found. The paid-promotion overlay defaults to *off* on purpose --
    // it is a disclosure, and removing one for everybody is not this tweak's call.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefHideAds: @YES,
        SCIPrefBackgroundPlay: @YES,
        SCIPrefBlockUpdateNag: @YES,
        SCIPrefHidePaidPromo: @NO,
        SCIPrefVerboseLogging: @NO,

        // The button beside You is on: a Download Centre nobody can find is a Download
        // Centre that does not exist. Saving to Photos automatically is off, which is
        // the whole point of having somewhere else to put a download.
        SCIPrefTabButton: @YES,
        SCIPrefShortsButton: @YES,
        SCIPrefAutoPhotos: @NO,

        // SponsorBlock on, and its three least arguable categories with it: a paid
        // plug, the creator's own promotion, and a subscribe reminder are what people
        // mean by "skip the sponsor".
        //
        // Intros, endcards, recaps, tangents and non-music sections stay off. Each of
        // those is content somebody chose to make, and deciding for every user that it
        // is worthless is not this tweak's call — the switches are right there.
        SCIPrefSponsorBlock: @YES,
        SCIPrefSBNotice: @YES,

        // The coloured markers on the progress bar. On, but it is the one switch here
        // that turns off view work rather than a feature -- so if a future YouTube
        // rewrites the bar, there is something to turn off that leaves skipping alone.
        SCIPrefSBMarkers: @YES,
        SCIPrefSBSponsor: @YES,
        SCIPrefSBSelfPromo: @YES,
        SCIPrefSBInteraction: @YES,
        SCIPrefSBIntro: @NO,
        SCIPrefSBOutro: @NO,
        SCIPrefSBPreview: @NO,
        SCIPrefSBFiller: @NO,
        SCIPrefSBMusicOffTopic: @NO,
    }];

    // Unconditional, and the only line here that is.
    //
    // 0.1.0 shipped with every way of telling whether the tweak had loaded sitting
    // behind a settings section that did not appear. One line at launch costs nothing
    // and means "is it even in there" is never a question again.
    NSLog(@"[AlbrhiYT] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // Said once, on the first launch after installing. Deliberately after everything else
    // in here: a greeting must never be the reason a hook did not get installed.
    [SCIYTWelcome showIfFirstRun];

    // Written once at launch and refreshed whenever a video is captured, so the
    // report is retrievable from the app's container even if no hook attached.
    [SCIYTDiagnostics writeReportToFile];
}
