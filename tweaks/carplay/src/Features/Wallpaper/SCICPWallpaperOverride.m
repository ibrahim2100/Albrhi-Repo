#import "SCICPWallpaperOverride.h"
#import "shared/src/SCICPPrefsKeys.h"

@implementation SCICPWallpaperOverride

+ (UIImage *)customImage {
    NSData *data = [NSData dataWithContentsOfFile:SCICPWallpaperImagePath];
    if (!data.length) return nil;

    return [UIImage imageWithData:data];
}

@end
