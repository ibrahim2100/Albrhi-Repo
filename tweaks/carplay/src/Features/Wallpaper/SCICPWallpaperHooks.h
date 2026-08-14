#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Overrides the CarPlay dashboard wallpaper with a user-chosen image, from inside
/// com.apple.CarPlayWallpaper -- Apple's own hidden system app that renders it.
///
/// Read CLAUDE.md's CarPlay section for how this was found: `CPWRootViewController`
/// resolves Apple's own wallpaperIdentifier into a UIImage and assigns it to its
/// `imageView` inside a private method, `-_updateWallpaperImage`. This hooks exactly
/// that one method, after Apple's own resolution has already run, and only replaces
/// the image when SCICPWallpaperOverride actually has one to offer -- nothing here
/// touches the identifier, the private wallpaper-preferences classes, or how Apple
/// decides which wallpaper to resolve in the first place, which is the part of this
/// system that was never fully mapped from two 90KB app binaries alone.
///
/// This is a normal app process, not SpringBoard: a mistake here can blank or crash
/// the CarPlay dashboard background, never the whole home-screen experience.
///
void SCICPInstallWallpaperHooks(void);

NS_ASSUME_NONNULL_END
