#import "YouTubeHeaders.h"
#import "Tweak.h"
#import "SCILog.h"
#import "Diagnostics/SCIYTDiagnostics.h"

NSString *SCIVersionString = @"v0.1.4";  // AlbrhiYT

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
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"verbose_logging": @NO,
    }];

    // Unconditional, and the only line here that is.
    //
    // 0.1.0 shipped with every way of telling whether the tweak had loaded sitting
    // behind a settings section that did not appear. One line at launch costs nothing
    // and means "is it even in there" is never a question again.
    NSLog(@"[AlbrhiYT] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // Written once at launch and refreshed whenever a video is captured, so the
    // report is retrievable from the app's container even if no hook attached.
    [SCIYTDiagnostics writeReportToFile];
}
