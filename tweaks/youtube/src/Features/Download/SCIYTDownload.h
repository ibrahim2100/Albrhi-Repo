#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Saving a video to Photos.
///
/// Three ways in: YouTube's own download button, a row in our panel, and — off by
/// default since 1.26.0 — holding the video itself.
///
/// **The button is the one that is meant to be used, and it is not placed, measured or
/// matched by title.** `YTSlimVideoDetailsActionView` declares `-hasOfflineButton`, so
/// the app itself says which of the buttons in that row is Download; see
/// SCIYTDownloadButton.x. Every earlier route this project has taken to "which button is
/// this" on any app has been wrong on some build.
///
/// **The hold was over YouTube's own hold.** It sits on YTPlayerViewController's `view`,
/// which never goes stale — but the app puts hold-to-speed-up on that same picture, and
/// two long presses over one surface meant a habit built around the app's feature started
/// producing a download sheet. Avoiding YouTube's view classes was the right instinct and
/// it solved the wrong problem: a gesture cannot go missing, and it can still be in the
/// way. Kept behind a switch, off, for anyone who learned it.
///
/// What it operates on is what the player is already holding: the streams captured for
/// the diagnostics page. So "download" means "save the video currently playing", which
/// is what someone with the panel open in front of a video means anyway.
///
/// Derived in method from YouMod by Tonwalter888 (GPLv3, as this is): where the format
/// list lives, that the real link is on the stream's nested formatStream rather than on
/// the stream, the itag sets that identify what iOS can actually play, and the query
/// handling that makes a link fetchable. The pipeline below is this project's own.
///
@interface SCIYTDownload : NSObject


/// Asks which quality, then downloads, merges if it must, and saves to Photos.
+ (void)presentFrom:(UIViewController *)presenter;

/// The same, for a video the caller can name.
///
/// Shorts needs this: what the tweak knows as "playing" follows YouTube's announcements, and
/// those run ahead into the clip being preloaded. The Shorts button reads the id off the
/// overlay it is drawn on and says so here. Passing nil is the same as the method above.
+ (void)presentFrom:(UIViewController *)presenter videoID:(NSString *)videoID;

/// A line for the diagnostics page: how many formats were found and whether any of
/// them carried a fetchable link.
+ (NSString *)diagnosticsSummary;

@end

NS_ASSUME_NONNULL_END
