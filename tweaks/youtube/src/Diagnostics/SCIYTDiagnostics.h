#import <UIKit/UIKit.h>

///
/// Runtime truth about this build, and about the last video the player was handed.
///
/// Instagram's equivalent page exists because two features were "fixed" repeatedly
/// against classes that were never instantiated. YouTube starts with the same page
/// for a sharper reason: how downloading can work at all depends on which stream
/// path a given build and account actually receives, and that is not readable from
/// the binary. It has to be printed from a real device.
///
@interface SCIYTDiagnostics : NSObject

/// Recorded by the playback hooks, read by the page. Nil until a video plays.
+ (void)recordPlayerResponse:(id)response;
+ (void)recordVideo:(id)video;

/// What the last video handed over, for anything that needs the streams rather than a
/// report of them — the downloader, in practice.
///
/// Exposed here rather than captured a second time: these hooks already run for the
/// report, and a second set watching the same two classes would be two things to keep
/// in step for no gain.
+ (id)lastStreamingData;

/// The player response captured from the overlay — a YTIPlayerResponse, and a third
/// place the formats might carry links. Held since 0.1.0 for the report, and never read
/// by the downloader until it turned out that which streaming data you ask is the whole
/// question.
+ (id)lastPlayerResponse;
+ (NSString *)lastVideoID;

/// The video the captured player response belongs to -- which is the video its HLS playlist
/// is for, and not necessarily the one playing or the last MLVideo built.
+ (NSString *)responseVideoID;

/// The stream object captured for one particular video, or nil.
///
/// Keyed rather than latest-only, because in Shorts the newest capture belongs to the clip
/// being preloaded and the one wanted is the capture before it.
+ (id)streamingDataForVideoID:(NSString *)videoID;

/// A player response filed under the video it belongs to.
///
/// Shorts is the reason this exists: it never builds an MLVideo, so nothing else in the
/// tweak ever learns which clip a capture is for.
+ (void)recordResponse:(id)response forVideo:(NSString *)videoID;
+ (id)responseForVideoID:(NSString *)videoID;

/// The video the player actually activated, which is not always the last MLVideo made.
///
/// A report showed SponsorBlock working on VTBoGy0EynQ while this page reported
/// XDRKSAqd4AA as the last video: MLVideo objects are created for videos the app is
/// preloading as well as the one on screen, and the download was asking YouTube about
/// whichever came last rather than the one being watched. Two ids, two different videos,
/// and a download that could only fail.
+ (void)recordActiveVideoID:(NSString *)videoID;
+ (NSString *)activeVideoID;

/// What the format request did, client by client. Recorded so a failure says which one
/// was asked and what it answered, instead of one sentence covering every cause.
///
/// Safe to call from any thread, which it has to be: the download records from its own
/// queues while the report is being rendered on the main one.
+ (void)recordStreamAttempt:(NSString *)line;
+ (void)clearStreamAttempts;

/// A snapshot of the lines recorded so far. Whoever enumerates must hold a copy.
+ (NSArray<NSString *> *)attempts;
+ (NSString *)lastVideoTitle;

/// Recorded by the settings hooks: the groups YouTube's settings screen is built
/// from, with the type of each. Those numbers cannot be read out of the binary, and
/// getting the wrong one is why 0.1.0 showed no section at all.
+ (void)recordSettingsGroups:(NSArray *)groups;

/// Recorded when the panel could not be built. It is caught rather than allowed to
/// reach the app, so it has to be written down somewhere or the failure is invisible.
+ (void)recordPanelFailure:(NSString *)reason;

/// The last thing SponsorBlock did, in one line.
///
/// Added because 0.3.0 shipped unable to read a video ID and there was no way to see
/// that from the phone: the feature simply never fired, which looks identical to "no
/// segments exist for this video" and to "the hook did not attach". Three different
/// faults with one symptom is exactly what this page exists to separate.
+ (void)recordSponsorState:(NSString *)state;

/// Which progress-bar class the markers were drawn on, and how many.
///
/// Separate from the state above because they answer different questions: that one says
/// whether segments were found, this one says whether the bar was. Three bar classes are
/// hooked and only one of them exists in any given build -- this reports which.
+ (void)recordMarkerBar:(NSString *)className count:(NSInteger)count;

/// What a like/dislike counter node said it held, before anything was written into it.
///
/// Which node is the dislike one is decided from its text, so the text is exactly what has
/// to be visible when it turns out to have picked the wrong one.
+ (void)recordCounterNode:(NSString *)text;
+ (NSArray<NSString *> *)counterNodes;

/// What happened when the Downloads tab tried to attach, and then to draw itself.
///
/// 0.18.0 reported nothing about the tab at all, so "the icon did not appear" had no
/// answer in the report -- it could not even say whether a tab was built.
+ (void)recordTabState:(NSString *)state;
+ (NSString *)tabState;

/// What the Shorts save button did, or why there is none.
+ (void)recordShortsButton:(NSString *)state;
+ (NSString *)shortsButtonState;

/// What the last tap on that button actually tried to save. Its own slot: the line above is
/// rewritten on every clip and buried this every time.
+ (void)recordShortsSave:(NSString *)detail;
+ (NSString *)shortsSaveState;

/// Why a saved file would not open, straight from AVFoundation.
+ (void)recordPlaybackFailure:(NSString *)detail;
+ (NSString *)playbackFailures;

/// When the feed filter refused to run because it would have dropped too much.
+ (void)recordFeedBrake:(NSString *)detail;

/// Whether an ad page in Shorts was seen, and refused.
+ (void)recordShortsAd:(NSString *)detail;
+ (NSString *)shortsAdState;

/// How much of the feed this run saw, and how much of it was dropped as promoted.
+ (void)recordFeedSections:(NSUInteger)seen dropped:(NSUInteger)dropped;
+ (NSString *)feedState;

/// The whole report as text: what the file holds and the copy button copies.
+ (NSString *)report;

/// The same report, bounded for the screen.
///
/// The full player response is a protobuf printed as text and runs to hundreds of
/// kilobytes on a real video. Handing that to a UITextView in one string is what made
/// this page take YouTube down when opened — and a crash inside the page that exists
/// to explain crashes is the worst one there is. The file keeps everything.
+ (NSString *)reportForDisplay;

/// YouTube's own version, for the identity card and the report.
+ (NSString *)appVersion;

/// Whether every class the features hook is actually present.
///
/// Read by the identity card so the answer is the first thing on the settings screen
/// rather than something to go looking for. Earlier versions buried it -- 0.1.0 put it
/// behind the very thing that had failed.
+ (BOOL)featuresAttached;

/// Writes the report to a file inside the app's own container, and returns its path.
///
/// 0.1.0 put the only way to read a diagnostic *inside* the settings section, so when
/// that section failed to appear there was no way to find out why -- the one failure
/// the page exists to explain was the one it could not explain. This is the way out
/// that does not depend on any hook having worked.
+ (NSString *)writeReportToFile;

+ (UIViewController *)viewController;

@end
