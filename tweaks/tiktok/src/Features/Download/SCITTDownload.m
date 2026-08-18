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

/// Which of `item.candidates` is being fetched, and what the ones already tried
/// turned out to be -- so a give-up message can name every link it rejected rather
/// than only the last.
@property (nonatomic, assign) NSUInteger candidateIndex;
@property (nonatomic, strong) NSMutableArray<NSString *> *rejected;
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

/// When it happened, and how long the process has been running.
///
/// **A stale record read as a fresh one cost three releases of misdiagnosis.** This line
/// carried the identical byte count and media id across v0.7.0, v0.7.1 and v0.8.0 reports,
/// and every one of those was read as evidence that the newest chain had just saved audio --
/// when in fact no new attempt had been made at all, because the button was in the wrong
/// place to be tapped. Three fixes were aimed at a sentence that had not changed because
/// nothing had happened.
///
/// So the record says its own age. A line from a previous launch, or from minutes before the
/// current build was installed, is now impossible to mistake for the last thing that ran.
static NSDate *sciLastDownloadAt = nil;

void SCITTRecordDownload(NSString *state) {
    sciLastDownloadState = state;
    sciLastDownloadAt = [NSDate date];
    SCILogV(@"download: %@", state);
}

NSString *SCITTDownloadReport(void) {
    if (!sciLastDownloadState) return @"nothing saved yet this launch";

    NSTimeInterval ago = [[NSDate date] timeIntervalSinceDate:sciLastDownloadAt];
    return [NSString stringWithFormat:@"%@ (%.0fs ago)", sciLastDownloadState, ago];
}

@implementation SCITTDownload

/// Saves every picture of a photo post, in order.
///
/// Fetched on a background queue because +dataWithContentsOfURL: blocks until each picture
/// arrives, and a post can hold eight of them -- doing that on the main thread would freeze
/// the feed for the whole download.
///
/// **Each picture is imported in its own change block.** One block for all of them would make
/// a single failure discard the entire post, and a post where seven of eight arrived is worth
/// keeping the seven. The counter reports both numbers for the same reason: "saved 6 of 8" and
/// "saved nothing" are different problems.
+ (void)savePhotos:(NSArray<NSURL *> *)urls {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized &&
            status != PHAuthorizationStatusLimited) {
            SCITTRecordDownload(@"Photos access refused");
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            __block NSUInteger saved = 0;

            for (NSURL *url in urls) {
                NSData *data = [NSData dataWithContentsOfURL:url];
                UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
                if (!image) continue;

                dispatch_semaphore_t wait = dispatch_semaphore_create(0);

                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL ok, NSError *error) {
                    if (ok) saved++;
                    else SCILogV(@"photo save: %@", error.localizedDescription);
                    dispatch_semaphore_signal(wait);
                }];

                // Waited on deliberately, one at a time. Photos serialises change requests
                // anyway, and firing eight at once produces eight interleaved completions
                // whose ordering in the album is then whatever the library felt like.
                dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
            }

            SCITTRecordDownload([NSString stringWithFormat:@"photo post — saved %lu of %lu",
                (unsigned long)saved, (unsigned long)urls.count]);
        });
    }];
}



+ (void)save:(SCITTMediaItem *)item {
    if (!item.url) return;

    // A photo post takes an entirely different path: several images, saved as images.
    //
    // The video path downloads to a temporary file and asks Photos to import it as a video,
    // and handing it a JPEG produces exactly the PHPhotosErrorDomain refusal that has already
    // appeared in one report -- Photos rejecting a file it was told was the wrong kind. The
    // two are separated here rather than inside the importer, so neither has to ask what the
    // other is doing.
    if (item.photoURLs.count) {
        [self savePhotos:item.photoURLs];
        return;
    }

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
    download.candidateIndex = 0;
    download.rejected = [NSMutableArray array];

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

    [download fetchCurrentCandidate];
}

/// The candidate list, or the single URL for an item that predates it.
- (NSArray<NSURL *> *)links {
    if (self.item.candidates.count) return self.item.candidates;
    return self.item.url ? @[self.item.url] : @[];
}

- (void)fetchCurrentCandidate {
    NSArray<NSURL *> *links = [self links];
    if (self.candidateIndex >= links.count) {
        // Every candidate fetched and every one of them turned out to be something
        // other than a video. Naming all of them is the point: one rejected link says
        // nothing, the whole list says which chain family to stop trusting.
        SCITTRecordDownload([NSString stringWithFormat:@"no candidate was a video — %@",
            [self.rejected componentsJoinedByString:@"; "]]);
        [self finish:NO message:SCILocalized(@"save_failed")];
        return;
    }

    NSURL *url = links[self.candidateIndex];
    [[self.session downloadTaskWithURL:url] resume];
    SCILogV(@"downloading candidate %lu/%lu: %@",
        (unsigned long)(self.candidateIndex + 1), (unsigned long)links.count, url);
}

/// Records why this candidate was not it, then fetches the next one.
- (void)rejectCandidate:(NSString *)reason {
    NSArray<NSURL *> *links = [self links];
    NSURL *url = self.candidateIndex < links.count ? links[self.candidateIndex] : nil;

    [self.rejected addObject:[NSString stringWithFormat:@"%@ (%@)",
        reason, url.lastPathComponent ?: @"?"]];

    self.candidateIndex++;
    [self fetchCurrentCandidate];
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
            [self rejectCandidate:[NSString stringWithFormat:@"HTTP %ld", (long)status]];
            return;
        }
    }

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
        [self rejectCandidate:[NSString stringWithFormat:@"not media, %llu bytes, %@",
            bytes, mime.length ? mime : @"no mime"]];
        return;
    }

    //
    // **Audio is now a rejected candidate, not an outcome.** This branch used to save
    // the file into Documents and report "sound saved" -- which is exactly what a real
    // device kept doing for a video, because `originURLList` reliably answers with the
    // *sound's* link and there was nothing to fall back to. There is now: every chain's
    // link is kept, so an audio-only file means "wrong candidate, try the next one"
    // rather than "this video is a song". Only when every candidate has been fetched and
    // every one of them lacked a video track is audio accepted as the honest answer --
    // handled in -fetchCurrentCandidate's own exhausted branch, which names all of them.
    //
    if (audioOnly) {
        [[NSFileManager defaultManager] removeItemAtURL:staged error:NULL];
        [self rejectCandidate:[NSString stringWithFormat:@"audio only, %llu bytes, %@",
            bytes, mime.length ? mime : @"no mime"]];
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
    // A transfer that failed outright is a rejected candidate like any other -- the
    // next link in the list may well be reachable when this one was not.
    [self rejectCandidate:[NSString stringWithFormat:@"transfer failed: %@",
        error.localizedDescription ?: @"no reason given"]];
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
