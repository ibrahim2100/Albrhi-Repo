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

/// Offers the two outcomes — the picture on its own, or a clip with the sound —
/// and carries out whichever is chosen. Call on the main thread; the rendering
/// happens off it, behind the transcode banner.
///
/// @param savePhoto  run when the picture alone is what the user wants, so the
///                   ordinary download stays the caller's business and this class
///                   never grows a second path into the photo library.
+ (void)offerForPhoto:(NSURL *)photo
                audio:(NSURL *)audio
            savePhoto:(void (^)(void))savePhoto;

@end

NS_ASSUME_NONNULL_END
