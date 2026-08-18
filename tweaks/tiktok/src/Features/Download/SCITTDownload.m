#import "SCITTDownload.h"
#import "../../Localization/SCILocalize.h"
#import "../../SCILog.h"
#import <ImageIO/ImageIO.h>
#import "modules/JGProgressHUD/JGProgressHUD.h"
#import "../../Prefs.h"
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
/// The HUD for a photo-post save, held while the images go one at a time.
static JGProgressHUD *sciPhotoHUD = nil;

+ (void)askThenSavePhotos:(SCITTMediaItem *)item {
    NSArray<NSURL *> *all = item.photoURLs;

    // One picture, or no idea which one is on screen: nothing to ask about.
    if (all.count < 2) {
        [self savePhotos:all];
        return;
    }

    NSURL *current = (item.photoIndex < all.count) ? all[item.photoIndex] : nil;
    if (!current) {
        [self savePhotos:all];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = [self topViewController];
        if (!presenter) {
            // Nothing to present from. Saving the one on screen is the conservative answer:
            // a post of sixteen arriving whole in Photos unasked is the complaint this exists
            // to answer, and the user can tap again for the rest.
            [self savePhotos:@[current]];
            return;
        }

        UIAlertController *sheet = [UIAlertController
            alertControllerWithTitle:SCILocalized(@"photos_ask_title")
                             message:nil
                      preferredStyle:UIAlertControllerStyleActionSheet];

        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"photos_save_this")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self savePhotos:@[current]];
        }]];

        NSString *allTitle = [NSString stringWithFormat:SCILocalized(@"photos_save_all"),
                              (unsigned long)all.count];
        [sheet addAction:[UIAlertAction actionWithTitle:allTitle
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self savePhotos:all];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"photos_cancel")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];

        // An action sheet with no anchor is a crash on iPad, and TikTok runs there.
        sheet.popoverPresentationController.sourceView = presenter.view;
        sheet.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(presenter.view.bounds),
                       CGRectGetMaxY(presenter.view.bounds) - 1, 1, 1);

        [presenter presentViewController:sheet animated:YES completion:nil];
    });
}

///
/// The measured byte length of a link, or 0 if it will not say.
///
/// A `HEAD` costs one round trip and answers the only question that has ever mattered here.
/// Every previous attempt at quality compared *names* -- which chain, which gear, which
/// accessor -- and a name is a claim about a file. `Content-Length` is the file.
///
/// Headers a plain `NSURLSession` request does not send.
///
/// The external HD service answered neither `HEAD` nor a range `GET` and measured 0.0 MB twice
/// over — while the same address works in a browser. NA9 sets request headers and installs a
/// redirect delegate for the same call, which is evidence rather than decoration: the service
/// declines a request that does not look like a browser. Applied to every measurement because
/// TikTok's own CDN does not mind, and a second code path for one host is a second thing to
/// get wrong.
static void SCITTAddBrowserHeaders(NSMutableURLRequest *request) {
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15"
                       " (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
   forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
}

///
/// Asks the external service for its HD link, or nil.
///
/// **`…/video/media/hdplay/<id>.mp4` is not an endpoint on its own** — it answers 400 for an id
/// the service has not been asked about, which is why the link measured 0.0 MB in two device
/// reports and why no `User-Agent` fixed it. The service is an API: one JSON request names the
/// links, and the shortcut only works afterwards. NA9 parses JSON for this call rather than
/// fetching a URL, which is the detail its binary was showing and I first read as decoration.
///
/// **Worth knowing before enabling it: for the video measured from a real report, `hd_size` was
/// 3,786,622 bytes — byte for byte the file this tweak already downloads internally.** The
/// external route is not a better file there; it is the same file fetched by a route that also
/// tells a third party what is being watched. Kept because it was asked for and because other
/// videos may differ, and it stays off by default.
static NSURL *SCITTExternalHDLink(NSString *identifier) {
    NSString *address = [NSString stringWithFormat:
        @"https://tikwm.com/api/?url=https://www.tiktok.com/@/video/%@&hd=1", identifier];

    NSURL *endpoint = [NSURL URLWithString:address];
    if (!endpoint) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.timeoutInterval = 12;
    SCITTAddBrowserHeaders(request);

    __block NSURL *resolved = nil;
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data.length) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            id payload = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;

            if ([payload isKindOfClass:[NSDictionary class]]) {
                // `hdplay` first, then the plain copy: both are watermark-free there, and the
                // second is still better than nothing when a post has no HD variant at all.
                for (NSString *key in @[@"hdplay", @"play"]) {
                    NSString *link = payload[key];
                    if ([link isKindOfClass:[NSString class]] && link.length) {
                        resolved = [NSURL URLWithString:link];
                        if (resolved) break;
                    }
                }
            }
        }
        dispatch_semaphore_signal(wait);
    }];
    [task resume];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 15ull * NSEC_PER_SEC));
    return resolved;
}

static long long SCITTMeasure(NSURL *url, NSString **outKind) {
    if (!url) return 0;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 8;
    SCITTAddBrowserHeaders(request);

    __block long long length = 0;
    __block NSString *kind = nil;
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        if (http.statusCode >= 200 && http.statusCode < 300) {
            length = response.expectedContentLength;

            // **The type was in the response all along and 0.14.0 threw it away.** Measuring
            // by size alone chose a 0.9 MB `audio/mpeg` over an .mp4 whose HEAD was refused --
            // saving the music, which this project has already recorded as worse than saving
            // nothing. Size only ever settles a tie *between videos*.
            kind = response.MIMEType.lowercaseString;
        }
        dispatch_semaphore_signal(wait);
    }];
    [task resume];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC));

    if (outKind) *outKind = kind;
    return length > 0 ? length : 0;
}

///
/// The same question asked a second way, for servers that refuse `HEAD`.
///
/// **A refused `HEAD` was scoring zero and sinking a link to the bottom — including the
/// external HD link the user deliberately switched on**, which is the whole point of that
/// switch, and including `bitrateModels`' own address. A one-byte range request is a `GET`, so
/// a server that serves the file at all answers it, and `Content-Range: bytes 0-0/12345` gives
/// the total in its last field.
static long long SCITTMeasureByRange(NSURL *url, NSString **outKind) {
    if (!url) return 0;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 8;
    [request setValue:@"bytes=0-0" forHTTPHeaderField:@"Range"];
    SCITTAddBrowserHeaders(request);

    __block long long length = 0;
    __block NSString *kind = nil;
    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        if (http.statusCode >= 200 && http.statusCode < 300) {
            kind = response.MIMEType.lowercaseString;

            NSString *range = http.allHeaderFields[@"Content-Range"];
            NSString *total = [[range componentsSeparatedByString:@"/"] lastObject];
            length = total.longLongValue;

            // A server that ignores the range and sends the file answers the question too.
            if (length <= 0 && response.expectedContentLength > 0) {
                length = response.expectedContentLength;
            }
        }
        dispatch_semaphore_signal(wait);
    }];
    [task resume];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 12ull * NSEC_PER_SEC));

    if (outKind) *outKind = kind;
    return length > 0 ? length : 0;
}

/// How a candidate ranks before its size is even looked at.
///
/// 2 answered as video, 1 would not say, 0 answered as audio. Audio never wins on size, no
/// matter how much larger it is, and a link whose server refuses `HEAD` still outranks it
/// because refusing to answer is not evidence of being the wrong thing.
static NSInteger SCITTKindRank(NSString *kind, NSURL *url) {
    NSString *extension = url.pathExtension.lowercaseString;

    if ([kind hasPrefix:@"audio/"] ||
        [@[@"mp3", @"m4a", @"aac", @"wav"] containsObject:extension]) return 0;

    if ([kind hasPrefix:@"video/"] ||
        [@[@"mp4", @"mov", @"m4v"] containsObject:extension]) return 2;

    return 1;
}

/// The last measurement, for the settings screen.
static NSString *sciMeasured = nil;

NSString *SCITTMeasuredReport(void) {
    return sciMeasured ?: @"nothing measured yet this launch";
}

///
/// Reorders an item's candidate links so the largest file is tried first.
///
/// **This replaces guessing which chain is better with asking.** TikTok populates the quality
/// ladder only with the gears it is currently streaming -- one report showed five gears up to
/// 720, the next showed a single `comet_lowest_540_1` -- so preferring the ladder takes the
/// worse file exactly when the app has not fetched the better one. Preferring
/// `downloadNoWatermarkURL` instead would be the same mistake pointing the other way. Neither
/// name is reliable; the byte count is.
///
/// Runs off the main thread and is skipped entirely if there is only one link.
///
/// Whether a link's own accessor name says it carries TikTok's watermark.
///
/// `downloadURL` and `h264DownloadURL` are the app's *watermarked* save copies;
/// `downloadNoWatermarkURL` and the bitrate ladder's `playAddr` are the clean ones. The
/// watermarked file is usually the largest on offer, so ranking by size alone stamps a
/// watermark on every download — which is what a device report showed. Nothing measurable in
/// the response says this; only the name does.
static BOOL SCITTOriginIsWatermarked(NSString *origin) {
    // **`h264DownloadURL` is no longer assumed watermarked — that was a guess from its name.**
    //
    // It measured 7.2 MB against tikwm's 5.3 and `bitrateModels`' 2.9 on the same video, and it
    // lost only because this function said so. Nothing was ever checked: `h264` names a *codec*,
    // and the two accessors that do state their nature state it plainly —
    // `downloadNoWatermarkURL` says there is none, `downloadURL` says it is the download copy.
    // `h264DownloadURL` says neither, and VibeTok uses it as its primary link.
    //
    // So it competes on size now, and the saved file answers the question the name could not.
    // If it comes back stamped, this list gains it again — with a device report behind it that
    // time rather than a reading of English.
    return [origin isEqualToString:@"downloadURL"];
}

+ (NSArray<NSURL *> *)orderByMeasuredSize:(NSArray<NSURL *> *)links
                                 origins:(NSArray<NSString *> *)origins {
    if (links.count < 2) return links;

    NSMutableArray<NSURL *> *measured = [NSMutableArray array];
    NSMutableDictionary<NSURL *, NSNumber *> *sizes = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSURL *, NSNumber *> *ranks = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *report = [NSMutableArray array];

    for (NSURL *url in links) {
        NSString *kind = nil;
        long long size = SCITTMeasure(url, &kind);
        if (size <= 0) {
            NSString *rangeKind = nil;
            size = SCITTMeasureByRange(url, &rangeKind);
            if (rangeKind.length) kind = rangeKind;
        }
        NSInteger rank = SCITTKindRank(kind, url);

        // A clean video outranks a watermarked one whatever the sizes say; among equals, size
        // decides. Three tiers rather than two, so a watermarked video still beats an unknown.
        //
        // **The index is the loop's own, not a search.** `-indexOfObject:` was used here and it
        // silently mislabelled every link the moment the external HD address was inserted at
        // the front: the origins list still described the original order, so each label named
        // the previous link's accessor. A parallel array must be walked in lockstep with the
        // thing it parallels, never re-found.
        NSUInteger index = [links indexOfObjectIdenticalTo:url];
        NSString *origin = index < origins.count ? origins[index] : nil;
        if (rank == 2 && SCITTOriginIsWatermarked(origin)) rank = 1;

        // Switching the external HD source on is a request for *that source*, not a hint to be
        // outvoted by an internal link that happens to measure larger. It ranks above them all
        // when it answers at all — and when it does not answer, it keeps its ordinary rank and
        // loses on the merits, so a service that is down costs the download nothing.
        if ([origin isEqualToString:@"tikwm HD"] && size > 0) rank = 3;

        sizes[url] = @(size);
        ranks[url] = @(rank);
        [measured addObject:url];
        [report addObject:[NSString stringWithFormat:@"%@ %.1f MB %@",
                           url.path.lastPathComponent ?: @"?", size / 1048576.0,
                           origin ?: (kind ?: @"?")]];
    }

    // Kind first, size second. A bigger audio file is still the wrong file, and a bigger
    // watermarked file is still a watermarked file.
    [measured sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        if (![ranks[a] isEqual:ranks[b]]) return [ranks[b] compare:ranks[a]];
        return [sizes[b] compare:sizes[a]];
    }];

    // A link that would not answer scores 0 and sinks to the bottom rather than being dropped:
    // a server that refuses HEAD still serves GET, and losing a working link to a measurement
    // that failed would be the same class of mistake as hiding the button when a lookup
    // returned nil.
    sciMeasured = [NSString stringWithFormat:@"%@ — took %@",
                   [report componentsJoinedByString:@", "],
                   measured.firstObject.path.lastPathComponent ?: @"?"];

    return measured;
}

+ (UIViewController *)topViewController {
    UIView *host = [self host];
    UIViewController *controller = host.window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

///
/// One change request, run and waited on, reporting whether Photos accepted it.
///
/// Photos serialises change requests anyway, so waiting costs nothing and buys ordering: eight
/// fired at once produce eight interleaved completions and an album in whatever order the
/// library felt like.
static BOOL SCITTPerformPhotoChange(void (^changes)(void), NSString **outError) {
    __block BOOL ok = NO;
    __block NSString *failure = nil;

    dispatch_semaphore_t wait = dispatch_semaphore_create(0);

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:changes
                                      completionHandler:^(BOOL success, NSError *error) {
        ok = success;
        if (!success) failure = error.localizedDescription;
        dispatch_semaphore_signal(wait);
    }];

    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));

    if (outError) *outError = failure;
    return ok;
}

///
/// Saves one downloaded picture, trying three ways and naming the one that worked.
///
/// **`PHPhotosErrorDomain 3302` is Photos refusing the *format*, not the bytes** — it arrived
/// for images `UIImage` had already decoded perfectly well, which rules out a bad download. The
/// cause is that a data resource carries no file name, so the library has to guess the type,
/// and TikTok serves these as WebP, which it will not take.
///
/// So the original bytes are offered *with* their own file name first — that is the only path
/// that saves the picture exactly as posted, no re-encode. If Photos still refuses the format,
/// the decoded image is re-encoded as JPEG, which it always accepts and which is a real loss
/// worth taking over saving nothing. The plain image request is kept last as the path that
/// worked before any of this.
static BOOL SCITTSavePhotoData(NSData *data, UIImage *image, NSURL *source,
                               NSString **outHow, NSString **outError) {
    NSString *name = source.lastPathComponent;
    if (!name.pathExtension.length) name = [name stringByAppendingPathExtension:@"jpg"];

    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
    options.originalFilename = name.length ? name : @"photo.jpg";

    NSString *error = nil;

    if (SCITTPerformPhotoChange(^{
        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
        [request addResourceWithType:PHAssetResourceTypePhoto data:data options:options];
    }, &error)) {
        if (outHow) *outHow = @"as posted";
        return YES;
    }

    // **Decoding through ImageIO rather than only UIImage.** A device report came back with
    // 3302 after all three attempts, which means the image was nil and only the first ran:
    // `UIImage` will not decode some of what TikTok serves, and the JPEG fallback was therefore
    // unreachable exactly when it was needed. `CGImageSourceCreateWithData` reads every format
    // the system has a decoder for, including the ones UIImage declines, so the re-encode path
    // is now available whenever anything at all can read the bytes.
    if (!image) {
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (source) {
            CGImageRef decoded = CGImageSourceCreateImageAtIndex(source, 0, NULL);
            if (decoded) {
                image = [UIImage imageWithCGImage:decoded];
                CGImageRelease(decoded);
            }
            CFRelease(source);
        }
    }

    if (image) {
        NSData *jpeg = UIImageJPEGRepresentation(image, 0.95);
        if (jpeg.length) {
            PHAssetResourceCreationOptions *asJPEG = [[PHAssetResourceCreationOptions alloc] init];
            asJPEG.originalFilename = @"photo.jpg";

            if (SCITTPerformPhotoChange(^{
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                [request addResourceWithType:PHAssetResourceTypePhoto data:jpeg options:asJPEG];
            }, &error)) {
                if (outHow) *outHow = @"re-encoded as JPEG";
                return YES;
            }
        }

        if (SCITTPerformPhotoChange(^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        }, &error)) {
            if (outHow) *outHow = @"via UIImage";
            return YES;
        }
    }

    if (outError) {
        *outError = [NSString stringWithFormat:@"%@ [tried: as posted%@]",
                     error ?: @"refused", image ? @", JPEG, UIImage" : @" only — undecodable"];
    }
    return NO;
}

+ (void)savePhotos:(NSArray<NSURL *> *)urls {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized &&
            status != PHAuthorizationStatusLimited) {
            SCITTRecordDownload(@"Photos access refused");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self report:SCILocalized(@"save_no_permission") ok:NO];
            });
            return;
        }

        // The same HUD the video path shows. A save with no indicator at all is
        // indistinguishable from a button that does nothing, which is how working code got
        // reported as broken.
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *host = [self host];
            if (!host) return;

            JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
            hud.indicatorView = [[JGProgressHUDPieIndicatorView alloc] init];
            hud.textLabel.text = SCILocalized(@"save_working");
            hud.progress = 0;
            [hud showInView:host];
            sciPhotoHUD = hud;
        });

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSUInteger saved = 0, noData = 0, refused = 0;
            NSString *firstError = nil;
            NSMutableSet<NSString *> *ways = [NSMutableSet set];

            for (NSURL *url in urls) {
                NSData *data = [NSData dataWithContentsOfURL:url];
                if (!data.length) { noData++; continue; }

                NSString *how = nil, *error = nil;
                if (SCITTSavePhotoData(data, [UIImage imageWithData:data], url, &how, &error)) {
                    saved++;
                    if (how) [ways addObject:how];
                } else {
                    refused++;
                    if (!firstError) firstError = error;
                }

                NSUInteger done = saved + noData + refused;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sciPhotoHUD setProgress:(float)done / (float)urls.count animated:YES];
                });
            }

            // Counted apart, because a download that never arrived and a library that refused
            // the file need different fixes and one number said only that nothing happened.
            NSMutableString *note = [NSMutableString stringWithFormat:@"photo post — saved %lu of %lu",
                (unsigned long)saved, (unsigned long)urls.count];
            if (ways.count) {
                [note appendFormat:@" (%@)",
                    [[ways allObjects] componentsJoinedByString:@", "]];
            }
            if (noData) [note appendFormat:@"; %lu never downloaded", (unsigned long)noData];
            if (refused) [note appendFormat:@"; %lu refused by Photos", (unsigned long)refused];
            if (firstError) [note appendFormat:@" (%@)", firstError];

            SCITTRecordDownload(note);

            NSUInteger finalSaved = saved;
            dispatch_async(dispatch_get_main_queue(), ^{
                [sciPhotoHUD dismiss];
                sciPhotoHUD = nil;

                NSString *message = urls.count > 1
                    ? [NSString stringWithFormat:SCILocalized(@"photos_saved_count"),
                       (unsigned long)finalSaved, (unsigned long)urls.count]
                    : SCILocalized(finalSaved ? @"save_done" : @"save_failed");
                [self report:message ok:(finalSaved == urls.count)];
            });
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
        [self askThenSavePhotos:item];
        return;
    }

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized &&
            status != PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self report:SCILocalized(@"save_no_permission") ok:NO];
            });
            return;
        }

        // Measured off the main thread: it is one HEAD per link and the feed keeps scrolling.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSMutableArray<NSURL *> *links = [item.candidates mutableCopy] ?: [NSMutableArray array];

            // Grown and shrunk together with `links`, because a parallel array that is only
            // sometimes updated is worse than none: the labels stay plausible while naming the
            // wrong thing, which is exactly what a device report showed.
            NSMutableArray<NSString *> *origins =
                [item.candidateOrigins mutableCopy] ?: [NSMutableArray array];
            while (origins.count < links.count) [origins addObject:@"?"];

            // The one link in this tweak that leaves TikTok, and only on request.
            //
            // NA9's HD button has been reliable for years across TikTok updates for a reason
            // that is not cleverness: it never touches the app's model chain at all, so there
            // was never an internal accessor in that path to break. It asks tikwm.com, keyed
            // by the post id.
            //
            // The cost is the whole reason this is a switch and not the default: it tells a
            // service unrelated to TikTok and unrelated to this tweak which video you are
            // watching -- the exact thing the three privacy switches beside it exist to stop.
            // Off unless someone turns it on, and its own row says what it does before they do.
            if (SCIPrefEnabled(SCIPrefExternalHD) && item.itemID.length) {
                NSURL *external = SCITTExternalHDLink(item.itemID);
                if (external) {
                    [links insertObject:external atIndex:0];
                    [origins insertObject:@"tikwm HD" atIndex:0];
                }
            }

            NSArray<NSURL *> *ordered = [self orderByMeasuredSize:links origins:origins];
            if (ordered.count) {
                item.candidates = ordered;
                item.url = ordered.firstObject;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self start:item];
            });
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
