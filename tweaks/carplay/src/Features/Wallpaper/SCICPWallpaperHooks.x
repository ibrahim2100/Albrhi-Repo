#import "SCICPWallpaperHooks.h"
#import "SCICPWallpaperOverride.h"
#import "SCILog.h"
#import "../../Diagnostics/SCICPDiagnostics.h"
#import <UIKit/UIKit.h>

/// Private, undeclared anywhere this project controls -- found by reading
/// CarPlayWallpaper.app's own compiled binary (Apple's, not a third party's), see
/// SCICPWallpaperHooks.h. Only the one property this file actually touches is
/// declared, which is what Logos needs to compile `self.imageView` at all.
@interface CPWRootViewController : UIViewController
@property (nonatomic, strong) UIImageView *imageView;
@end

%hook CPWRootViewController

- (void)_updateWallpaperImage {
    %orig;

    UIImage *custom = [SCICPWallpaperOverride customImage];
    if (!custom) {
        SCILogV(@"wallpaper: no custom image set — Apple's own wallpaper stands");
        return;
    }

    self.imageView.image = custom;
    SCILogV(@"wallpaper: custom image applied (%.0fx%.0f)",
            custom.size.width, custom.size.height);
    [SCICPDiagnostics record:[NSString stringWithFormat:
        @"wallpaper: custom image applied (%.0fx%.0f)",
        custom.size.width, custom.size.height]];
}

%end

void SCICPInstallWallpaperHooks(void) {
    %init;
    SCILogV(@"wallpaper: hook installed");
    [SCICPDiagnostics record:@"wallpaper: hook installed"];
}
