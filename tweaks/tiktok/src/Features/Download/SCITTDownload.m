#import "SCITTDownload.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"
#import "modules/JGProgressHUD/JGProgressHUD.h"
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface SCITTDownload () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) SCITTMediaItem *item;
@property (nonatomic, strong) JGProgressHUD *hud;
@property (nonatomic, strong) NSURLSession *session;
@end

/// Kept alive by hand while it runs -- an NSURLSession retains its delegate, but
/// nothing retains the object here, so without this it is released the moment +save:
/// returns and the download stops with no error and no callback. Locket's and X's own
/// downloaders keep the same set for the same reason.
static NSMutableSet<SCITTDownload *> *_running = nil;

/// What the last save attempt actually did, in the words of whatever refused it.
///
/// "Couldn't save it" on a HUD is all a user needs and nothing a fix can be built
/// from: an HTTP 403 on the resolved link, a Photos library that will not decode the
/// file, and a zero-byte download that answered 200 all look identical from there and
/// need entirely different fixes. Recorded here and shown on the status screen for
/// the same reason every other diagnostic in this tweak exists.
static NSString *sciLastDownloadState = nil;

void SCITTRecordDownload(NSString *state) {
    sciLastDownloadState = state;
    SCILogV(@"download: %@", state);
}

NSString *SCITTDownloadReport(void) {
    return sciLastDownloadState ?: @"nothing saved yet";
}

@implementation SCITTDownload

+ (void)save:(SCITTMediaItem *)item {
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

+ (void)start:(SCITTMediaItem *)item {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ _running = [NSMutableSet set]; });

    SCITTDownload *download = [[SCITTDownload alloc] init];
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

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    download.session = [NSURLSession sessionWithConfiguration:configuration
                                                     delegate:download
                                                delegateQueue:nil];

    @synchronized (_running) { [_running addObject:download]; }

    [[download.session downloadTaskWithURL:item.url] resume];
    SCILogV(@"downloading %@", item.url);
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
    // TikTok hands out a finished MP4 for a video and either an MP4 or an M4A for a
    // song under this same URL shape. The path extension on the URL actually asked
    // for is checked first and the response's own MIME type only when that is
    // inconclusive -- a server that answers a generic or missing Content-Type for a
    // link whose own path plainly ends `.mp4` was reported saving a real video as
    // "sound saved", which MIME-only detection cannot tell apart from a genuine
    // audio-only link with the same gap.
    // An HTTP error answers with a body like any other response, and NSURLSession
    // hands that body over as a perfectly successful download -- so a 403 on the
    // resolved link arrives here as an error page saved with a .mp4 name, which
    // Photos then refuses for reasons that say nothing about the real cause.
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger status = ((NSHTTPURLResponse *)task.response).statusCode;
        if (status < 200 || status >= 300) {
            [[NSFileManager defaultManager] removeItemAtURL:location error:NULL];
            SCITTRecordDownload([NSString stringWithFormat:@"server answered HTTP %ld", (long)status]);
            [self finish:NO message:SCILocalized(@"save_failed")];
            return;
        }
    }

    NSURL *sourceURL = task.originalRequest.URL ?: task.currentRequest.URL;
    NSString *pathExtension = sourceURL.pathExtension.lowercaseString;
    NSString *mime = task.response.MIMEType.lowercaseString ?: @"";

    NSSet<NSString *> *videoExtensions = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"webm"]];
    NSSet<NSString *> *audioExtensions = [NSSet setWithArray:@[@"m4a", @"mp3", @"aac", @"wav"]];

    BOOL audioOnly;
    if ([videoExtensions containsObject:pathExtension]) {
        audioOnly = NO;
    } else if ([audioExtensions containsObject:pathExtension]) {
        audioOnly = YES;
    } else {
        audioOnly = [mime hasPrefix:@"audio/"];
    }
    NSString *extension = audioOnly ? @"m4a" : @"mp4";

    NSString *name = [NSString stringWithFormat:@"tiktok-%@.%@",
        [[NSUUID UUID] UUIDString], extension];
    NSURL *staged = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];

    NSError *move = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:staged error:&move]) {
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    // Photos has no concept of a bare audio file, so a song is kept in the app's own
    // Documents instead of asking a library that would always refuse it -- no
    // PHPhotoLibrary round trip needed for something that was never going there.
    if (audioOnly) {
        NSURL *documents = [[[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        NSURL *kept = [documents URLByAppendingPathComponent:staged.lastPathComponent];
        BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:staged toURL:kept error:NULL];
        SCITTRecordDownload(moved
            ? [NSString stringWithFormat:@"saved as audio (path .%@, mime %@)",
                pathExtension.length ? pathExtension : @"none", mime.length ? mime : @"none"]
            : @"audio move failed");
        [self finish:moved message:SCILocalized(moved ? @"save_done_audio" : @"save_failed")];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:staged];
    } completionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        if (success) {
            SCITTRecordDownload(@"saved to Photos");
            [self finish:YES message:SCILocalized(@"save_done")];
            return;
        }
        // Named, not just "couldn't save it". Photos refuses a video for reasons that
        // need opposite fixes -- a file it will not decode, a permission narrower than
        // it appeared, a zero-length download that answered 200 -- and the message
        // shown so far could not tell any of them apart.
        SCITTRecordDownload([NSString stringWithFormat:@"Photos refused: %@",
            error.localizedDescription ?: @"no reason given"]);
        [self finish:NO message:SCILocalized(@"save_failed")];
    }];
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (!error) return;
    SCITTRecordDownload([NSString stringWithFormat:@"transfer failed: %@",
        error.localizedDescription ?: @"no reason given"]);
    [self finish:NO message:SCILocalized(@"save_failed")];
}

- (void)finish:(BOOL)success message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud dismissAnimated:NO];
        self.hud = nil;

        [SCITTDownload report:message ok:success];

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
