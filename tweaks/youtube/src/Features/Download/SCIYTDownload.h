#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Saving a video to Photos.
///
/// The whole feature hangs off one entry point because there is only one way in: the
/// panel, opened with two fingers over the player. **No view of YouTube's is hooked to
/// get here**, and that is the design rather than a shortcut.
///
/// Every other tweak that downloads puts a button in YouTube's own player controls,
/// which means hooking view classes that get renamed between releases — this project's
/// own survey found nineteen dead class names in one such tweak. A row in our panel
/// cannot go stale that way, because the panel is ours.
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

/// Whether there is anything to download — a video has played and offered formats.
+ (BOOL)available;

/// Asks which quality, then downloads, merges if it must, and saves to Photos.
+ (void)presentFrom:(UIViewController *)presenter;

/// A line for the diagnostics page: how many formats were found and whether any of
/// them carried a fetchable link.
+ (NSString *)diagnosticsSummary;

@end

NS_ASSUME_NONNULL_END
