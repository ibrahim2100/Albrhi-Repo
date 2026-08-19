#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../InstagramHeaders.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The single entry point for downloading media.
///
/// Before this existed, each surface — feed video, reel, story, the inline button —
/// built its own download call. The quality picker was wired into exactly one of
/// them, so "choose quality before download" silently did nothing everywhere else.
///
/// Every path now funnels through here, which owns the whole decision chain:
/// quality picker → queue or direct → the right delegate for the media kind.
///

@interface SCIMediaDownloader : NSObject

/// Downloads a video, offering the resolution picker first when enabled and more
/// than one rendition exists.
/// @param anchor The view an iPad action sheet points at. Required on iPad.
+ (void)downloadVideo:(IGVideo *)video
          sourceLabel:(nullable NSString *)sourceLabel
               anchor:(nullable UIView *)anchor;

/// Downloads an already-resolved URL. Used for photos and audio, which have no
/// rendition choice.
+ (void)downloadURL:(NSURL *)url
        sourceLabel:(nullable NSString *)sourceLabel
              isVideo:(BOOL)isVideo;

/// Resolves an IGMedia-like object to its video or photo and downloads it.
/// Video wins when both are present.
+ (void)downloadMedia:(id)media
          sourceLabel:(nullable NSString *)sourceLabel
               anchor:(nullable UIView *)anchor;


/// Finds the currently-visible story media inside a view hierarchy and downloads
/// it. Powers the on-screen story download button.
+ (void)downloadVisibleStoryInView:(UIView *)root anchor:(nullable UIView *)anchor;

/// Whether this media has a video that can actually be resolved to a URL right now.
///
/// Exposed so the button's own media search can *prefer* a candidate that answers
/// YES — see SCIMediaDeclaresVideo below for why "NO" is not the same as "photo".
+ (BOOL)hasPlayableVideo:(nullable IGVideo *)video;

/// Whether this media says it is a video, regardless of whether one can be resolved.
///
/// **The distinction this whole pair exists for.** `+hasPlayableVideo:` answers "is
/// there a playable video *right now*", and a repost answers NO to that while still
/// being a video: Instagram models a repost as `IGRepostModel`, which carries only a
/// `mediaId` string, so the `IGMedia` behind it is built with `-initWithPk:` and is a
/// stub until fetched — `-needsFetch` / `-needsMediaFetch` are its own declared
/// accessors, and `-coverPhotoDidPartiallyLoad` says the cover arrives first. Its
/// cover photo resolves, its `videoVersions` are empty, and reading NO as "therefore a
/// photo" is what saved the cover image when a video was asked for.
+ (BOOL)mediaDeclaresVideo:(nullable id)media;

@end

NS_ASSUME_NONNULL_END
