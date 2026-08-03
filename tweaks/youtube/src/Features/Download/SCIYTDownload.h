#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Saving a video to Photos.
///
/// Two ways in, and **no view of YouTube's is hooked to reach either**: a row in our own
/// panel, and holding the video itself.
///
/// The hold is on YTPlayerViewController's own `view` — a class already verified and
/// already hooked, and a property that belongs to UIViewController rather than to
/// YouTube. So the gesture sits over the picture without depending on a single one of
/// YouTube's view classes, nineteen of which this project's own survey found missing
/// from the build a well-known tweak ships for.
///
/// That is the difference worth keeping: every other tweak that downloads puts a button
/// inside YouTube's player controls, which means hooking the view hierarchy that gets
/// renamed between releases. A gesture on a controller's view cannot go stale that way.
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
