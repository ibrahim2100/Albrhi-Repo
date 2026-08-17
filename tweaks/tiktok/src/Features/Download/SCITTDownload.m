#import "SCITTDownload.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"
#import "modules/JGProgressHUD/JGProgressHUD.h"
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

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
    NSString *mime = task.response.MIMEType.lowercaseString ?: @"";
    unsigned long long bytes =
        [[[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:NULL] fileSize];

    //
    // **Asked of the file, not of its name.** Both the URL's path extension and the
    // response's MIME type were tried in turn across two releases and both were wrong
    // on a real device: a genuine video kept saving as "sound saved", which is the
    // audio branch below being taken for a file that plainly has a video track. This
    // project's own ground rule already covers exactly this -- "a non-nil object is not
    // a working object; check that a thing can actually do its job, not that it is
    // non-null" -- and the same applies to a file's kind. AVFoundation reading the
    // downloaded file's own track list is the measurement; an extension on a URL that
    // may carry query parameters, no path at all, or a CDN's own naming is a guess.
    //
    NSURL *staged = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"tiktok-%@.mp4", [[NSUUID UUID] UUIDString]]]];

    [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];

    NSError *move = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:staged error:&move]) {
        SCITTRecordDownload([NSString stringWithFormat:@"could not stage the file: %@",
            move.localizedDescription ?: @"no reason given"]);
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:staged options:nil];
    NSUInteger videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo].count;
    NSUInteger audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio].count;
    BOOL audioOnly = (videoTracks == 0 && audioTracks > 0);

    // Neither kind of track at all is a file that is not media -- an error page, a
    // truncated transfer, an HTML redirect that answered 200. Saying so is worth far
    // more than handing it to Photos and reporting whatever Photos makes of it.
    if (videoTracks == 0 && audioTracks == 0) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        SCITTRecordDownload([NSString stringWithFormat:
            @"not playable media — %llu bytes, mime %@, no video or audio track (link: %@)",
            bytes, mime.length ? mime : @"none", sourceURL.host ?: @"?"]);
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    // Photos has no concept of a bare audio file, so a song is kept in the app's own
    // Documents instead of asking a library that would always refuse it. Reached only
    // when the file itself genuinely carries no video track.
    if (audioOnly) {
        NSURL *documents = [[[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        NSURL *kept = [documents URLByAppendingPathComponent:
            [staged.lastPathComponent.stringByDeletingPathExtension
                stringByAppendingPathExtension:@"m4a"]];
        BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:staged toURL:kept error:NULL];
        SCITTRecordDownload(moved
            ? [NSString stringWithFormat:
                @"saved as audio — the file really has no video track (%llu bytes, mime %@)",
                bytes, mime.length ? mime : @"none"]
            : @"audio move failed");
        [self finish:moved message:SCILocalized(moved ? @"save_done_audio" : @"save_failed")];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:staged];
    } completionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        if (success) {
            SCITTRecordDownload([NSString stringWithFormat:
                @"saved to Photos — %lu video / %lu audio track(s), %llu bytes",
                (unsigned long)videoTracks, (unsigned long)audioTracks, bytes]);
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
