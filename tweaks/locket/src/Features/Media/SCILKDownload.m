#import "SCILKDownload.h"
#import "Localization/SCILocalize.h"
#import "SCILog.h"
#import "modules/JGProgressHUD/JGProgressHUD.h"
#import <Photos/Photos.h>

@interface SCILKDownload () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) SCILKMediaItem *item;
@property (nonatomic, strong) JGProgressHUD *hud;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) BOOL isVideo;
@end


/// Kept alive by hand while it runs.
///
/// An NSURLSession retains its delegate, but nothing retains the object here, so without
/// this it is released the moment `+save:` returns and the download stops with no error and
/// no callback — a failure that looks exactly like a slow network. The X tweak's downloader
/// carries the same set for the same reason.
static NSMutableSet<SCILKDownload *> *_running = nil;

@implementation SCILKDownload

+ (void)save:(SCILKMediaItem *)item {
    if (!item.url) return;

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                handler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized &&
                status != PHAuthorizationStatusLimited) {
                [self report:SCILocalized(@"save_no_permission") ok:NO];
                return;
            }
            [self start:item];
        });
    }];
}

+ (void)start:(SCILKMediaItem *)item {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ _running = [NSMutableSet set]; });

    SCILKDownload *download = [[SCILKDownload alloc] init];
    download.item = item;

    UIView *host = [self host];
    if (host) {
        JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
        hud.indicatorView = [[JGProgressHUDPieIndicatorView alloc] init];
        hud.textLabel.text = SCILocalized(@"save_working");
        hud.progress = 0;
        [hud showInView:host];
        download.hud = hud;
    }

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    download.session = [NSURLSession sessionWithConfiguration:configuration
                                                     delegate:download
                                                delegateQueue:nil];

    @synchronized (_running) { [_running addObject:download]; }

    [[download.session downloadTaskWithURL:item.url] resume];
    SCILogV(@"downloading moment %@", item.url);
}

+ (UIView *)host {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return nil;
}

#pragma mark - Session

- (void)URLSession:(NSURLSession *)session
                       downloadTask:(NSURLSessionDownloadTask *)task
                       didWriteData:(int64_t)wrote
                  totalBytesWritten:(int64_t)written
          totalBytesExpectedToWrite:(int64_t)expected {
    if (expected <= 0) return;
    double fraction = (double)written / (double)expected;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud setProgress:(float)fraction animated:YES];
    });
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)task
didFinishDownloadingToURL:(NSURL *)location {
    // Kind and extension from the response, because the URL is an opaque token. Photos
    // rejects a video handed to it under an image extension without a word, so getting this
    // right off the content type is not cosmetic.
    NSString *mime = task.response.MIMEType.lowercaseString ?: @"";
    self.isVideo = [mime hasPrefix:@"video/"];
    NSString *extension = self.isVideo ? @"mp4" : @"jpg";
    if ([mime isEqualToString:@"image/png"]) extension = @"png";
    if ([mime isEqualToString:@"image/heic"]) extension = @"heic";
    if ([mime isEqualToString:@"video/quicktime"]) extension = @"mov";

    NSString *name = [NSString stringWithFormat:@"locket-%@.%@",
        [[NSUUID UUID] UUIDString], extension];
    NSURL *staged = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];

    NSError *move = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:staged error:&move]) {
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    BOOL video = self.isVideo;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        if (video) {
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:staged];
        } else {
            [PHAssetCreationRequest creationRequestForAssetFromImageAtFileURL:staged];
        }
    } completionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        if (!success) SCILogV(@"photos refused: %@", error);
        [self finish:success message:SCILocalized(success ? @"save_done" : @"save_failed")];
    }];
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (error) [self finish:NO message:SCILocalized(@"save_failed")];
}

- (void)finish:(BOOL)success message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud dismissAnimated:NO];
        self.hud = nil;

        [SCILKDownload report:message ok:success];

        [self.session invalidateAndCancel];
        @synchronized (_running) { [_running removeObject:self]; }
    });
}

+ (void)report:(NSString *)message ok:(BOOL)ok {
    UIView *host = [self host];
    if (!host) return;

    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.indicatorView = ok
        ? [[JGProgressHUDSuccessIndicatorView alloc] init]
        : [[JGProgressHUDErrorIndicatorView alloc] init];
    hud.textLabel.text = message;

    [hud showInView:host];
    [hud dismissAfterDelay:2.0];
}

@end
