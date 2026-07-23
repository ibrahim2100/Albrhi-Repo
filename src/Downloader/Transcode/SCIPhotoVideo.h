#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Turns a photo that carries audio into a video — beta.
///
/// Instagram plays music over still photos in reels and in the feed, but a
/// download only ever gives back the picture, and the sound is lost. This renders
/// the photo for a chosen number of seconds with that audio underneath, so what
/// gets saved is what was actually playing.
///
/// The frames are all identical, so H.264 encodes every one after the first to
/// almost nothing — a minute of a still image costs little more than a few
/// seconds of it.
///
@interface SCIPhotoVideo : NSObject

/// The longest clip on offer. Reel audio can run for minutes, and beyond this the
/// wait stops being worth the result.
+ (NSTimeInterval)maximumDuration;

/// Asks how long the clip should be, then renders and saves it. Call on the main
/// thread; the work happens off it, behind the transcode banner.
+ (void)offerForPhoto:(NSURL *)photo audio:(NSURL *)audio;

@end

NS_ASSUME_NONNULL_END
