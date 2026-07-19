#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import "../../modules/JGProgressHUD/JGProgressHUD.h"

#import "../InstagramHeaders.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"

#import "Manager.h"

@interface SCIDownloadDelegate : NSObject <SCIDownloadDelegateProtocol>

typedef NS_ENUM(NSUInteger, DownloadAction) {
    share,
    quickLook,
    saveToPhotos
};
@property (nonatomic, readonly) DownloadAction action;
@property (nonatomic, readonly) BOOL showProgress;

@property (nonatomic, strong) SCIDownloadManager *downloadManager;
@property (nonatomic, strong) JGProgressHUD *hud;

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress;

- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel;

/// Writes an already-downloaded local file to the photo library, honouring the
/// `custom_album` preference. Used by the download queue, which fetches the file
/// itself and only needs the final save step.
+ (void)saveLocalFileToPhotos:(NSURL *)fileURL;

@end