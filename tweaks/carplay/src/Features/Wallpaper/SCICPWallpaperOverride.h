#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Reads the image the panel's CarPlay settings page wrote, if any.
///
/// A file rather than a preference value -- see SCICPWallpaperImagePath in
/// shared/src/SCICPPrefsKeys.h for why -- and read fresh on every call rather than
/// cached: this fires once per CarPlay connection, not on any hot path, and a
/// cache would be one more thing to invalidate correctly for no measurable benefit.
///
@interface SCICPWallpaperOverride : NSObject

/// The custom wallpaper image, or nil if none has been chosen (or the file could
/// not be read) -- nil means "leave Apple's own wallpaper alone", never a crash.
+ (nullable UIImage *)customImage;

@end

NS_ASSUME_NONNULL_END
