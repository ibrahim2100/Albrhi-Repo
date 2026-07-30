#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The choice offered when a photo carries audio: keep the picture, or take it as
/// a clip with the sound.
///
/// A plain action sheet listing durations reads as though the video is the only
/// option and the user is merely picking its length. This puts the two outcomes
/// side by side first, and only asks about length once a clip is what they want —
/// so saving the photo stays one tap, exactly as it was before the feature
/// existed.
///
@interface SCIPhotoVideoSheet : NSObject

/// @param onPhoto  chosen "just the photo"
/// @param onVideo  chosen a clip, with the length in seconds
+ (void)presentWithOnPhoto:(void (^)(void))onPhoto
                   onVideo:(void (^)(NSTimeInterval seconds))onVideo;

@end

NS_ASSUME_NONNULL_END
