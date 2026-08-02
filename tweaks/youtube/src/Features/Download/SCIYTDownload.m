#import "SCIYTDownload.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "SCIYTStreamAPI.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/message.h>

///
/// One playable format.
///
@interface SCIYTFormat : NSObject
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, assign) NSInteger itag;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger fps;
@property (nonatomic, assign) long long bitrate;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) BOOL hasAudio;
@end

@implementation SCIYTFormat
@end


#pragma mark - Reading the streams

///
/// The helpers that read the app's own stream objects used to sit here.
///
/// They asked MLRemoteStream, and the formatStream nested inside it, for a link under
/// every name a link might have. A report from a real device settled it: every stream
/// answers -URL with "?cpn=…" — a query fragment — because this build fetches ranges
/// over the piecewise protocol rather than downloading a file. There is no link to
/// find under any name, and more probing would not have produced one.
///
/// Formats come from a fresh player response now. See SCIYTStreamAPI.
///
///
/// itags iOS can actually play, listed rather than inferred.
///
/// A MIME type of "video/mp4" is not enough: YouTube serves VP9 and AV1 under container
/// names iOS will happily download and then refuse to play, and the result is a file in
/// Photos that shows a black frame. The itag says exactly which codec is inside.
///
/// H.264 video, and AAC audio. VP9 and AV1 are deliberately absent — the Instagram side
/// of this repository transcodes AV1 on device and it costs minutes of battery per clip;
/// doing that here before the plain path is proven would be building the hard half first.
///
static NSSet<NSNumber *> *SCIPlayableVideoItags(void) {
    static NSSet *itags = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        itags = [NSSet setWithArray:@[
            @18, @22,                                  // muxed: video and audio in one file
            @160, @133, @134, @135, @136, @137,        // H.264 video-only, 144p → 1080p
            @298, @299,                                // H.264 60fps, 720p and 1080p
            @264, @266,                                // H.264 1440p and 2160p
        ]];
    });
    return itags;
}

static NSSet<NSNumber *> *SCIPlayableAudioItags(void) {
    static NSSet *itags = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // AAC in an MP4 container. Opus (249/250/251) is left out for the same reason
        // VP9 is: iOS will not put it in a .mp4 alongside H.264.
        itags = [NSSet setWithArray:@[@139, @140, @141, @256, @258]];
    });
    return itags;
}

/// The two itags that carry sound in the same file as the picture.
static BOOL SCIItagIsMuxed(NSInteger itag) {
    return itag == 18 || itag == 22;
}

///
/// The link, made fetchable.
///
/// Two changes, both from YouMod and both load-bearing:
///
///   `n` removed — a parameter that throttles the transfer to roughly playback speed,
///   which turns a two-minute download into the length of the video.
///
///   `ratebypass=yes` added, which asks for the whole file rather than a stream.
///
/// The cpn is left alone if one is already there. It identifies the playback session
/// and the URL arrives carrying it.
///
static NSString *SCIPreparedURL(NSString *urlString) {
    if (!urlString.length) return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (!components) return urlString;

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    BOOL hasRateBypass = NO;

    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"n"]) continue;
        if ([item.name isEqualToString:@"ratebypass"]) hasRateBypass = YES;
        [items addObject:item];
    }

    if (!hasRateBypass) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"ratebypass" value:@"yes"]];
    }

    components.queryItems = items;
    return components.string ?: urlString;
}


@implementation SCIYTDownload

#pragma mark - Discovery

///
/// Why the last scan produced what it did.
///
/// "Nothing to download" is the least useful sentence this tweak could say, and it is
/// what 0.5.0 said for every one of three different causes: no streaming data at all,
/// formats with no fetchable link, and formats in a codec iOS will not play. Those need
/// three different answers, and telling them apart on a device meant reading the
/// diagnostics page — for a message that could have named the reason itself.
///
static NSInteger sciSeen = 0;
static NSInteger sciNoURL = 0;
static NSInteger sciUnplayable = 0;

/// Turns one JSON format object into a format we can use, or nil.
+ (SCIYTFormat *)formatFromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;

    NSInteger itag = [json[@"itag"] respondsToSelector:@selector(integerValue)]
        ? [json[@"itag"] integerValue] : 0;
    if (!itag) return nil;

    sciSeen++;

    BOOL isVideo = [SCIPlayableVideoItags() containsObject:@(itag)];
    BOOL isAudio = [SCIPlayableAudioItags() containsObject:@(itag)];
    if (!isVideo && !isAudio) {
        sciUnplayable++;
        return nil;
    }

    NSString *url = json[@"url"];
    if (![url isKindOfClass:[NSString class]] || ![url hasPrefix:@"http"]) {
        sciNoURL++;
        return nil;
    }

    SCIYTFormat *format = [[SCIYTFormat alloc] init];
    format.itag = itag;
    format.urlString = SCIPreparedURL(url);
    format.isVideo = isVideo;
    format.hasAudio = isAudio || SCIItagIsMuxed(itag);
    format.height = [json[@"height"] respondsToSelector:@selector(integerValue)]
        ? [json[@"height"] integerValue] : 0;
    format.fps = [json[@"fps"] respondsToSelector:@selector(integerValue)]
        ? [json[@"fps"] integerValue] : 0;
    format.bitrate = [json[@"bitrate"] respondsToSelector:@selector(longLongValue)]
        ? [json[@"bitrate"] longLongValue] : 0;
    format.qualityLabel = [json[@"qualityLabel"] isKindOfClass:[NSString class]]
        ? json[@"qualityLabel"] : nil;

    return format;
}

/// Every usable format in a streaming-data dictionary.
+ (NSArray<SCIYTFormat *> *)formatsFromStreamingData:(NSDictionary *)streamingData {
    sciSeen = 0;
    sciNoURL = 0;
    sciUnplayable = 0;

    if (![streamingData isKindOfClass:[NSDictionary class]]) return @[];

    NSMutableArray<SCIYTFormat *> *out = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];

    for (NSString *key in @[@"adaptiveFormats", @"formats"]) {
        NSArray *list = streamingData[key];
        if (![list isKindOfClass:[NSArray class]]) continue;

        for (NSDictionary *entry in list) {
            SCIYTFormat *format = [self formatFromJSON:entry];
            if (!format || [seen containsObject:@(format.itag)]) continue;

            [seen addObject:@(format.itag)];
            [out addObject:format];
        }
    }

    SCILogV(@"download: %ld seen, %ld unplayable, %ld without a link, %lu usable",
            (long)sciSeen, (long)sciUnplayable, (long)sciNoURL, (unsigned long)out.count);

    return out;
}

/// The sentence shown when nothing can be saved, naming which of the three walls it hit.
+ (NSString *)refusalReason {
    if (sciSeen == 0) {
        return SCILocalized(@"dl_why_no_formats");
    }

    // The link comes first, and getting that order wrong made an earlier version of
    // this message actively misleading. A real report had twelve formats: eight in VP9
    // and AV1, and four in H.264 that this tweak accepts. It said "all in a codec iOS
    // will not play" — because eight is more than four — when what actually stopped the
    // download was that those four carried no link.
    //
    // Anything that survives the codec check and still cannot be fetched is the wall.
    // The codec only matters when nothing survived it at all.
    if (sciNoURL > 0) {
        return [NSString stringWithFormat:SCILocalized(@"dl_why_no_urls"), (long)sciNoURL];
    }
    if (sciUnplayable > 0) {
        return [NSString stringWithFormat:SCILocalized(@"dl_why_unplayable_api"),
                (long)sciUnplayable];
    }
    return SCILocalized(@"dl_why_unknown");
}

+ (NSString *)diagnosticsSummary {
    // Deliberately not a live count any more. Formats come from a request to YouTube
    // now, and a diagnostics page that fired one off every time it was opened would be
    // asking about the user's video without being told to.
    //
    // What it can report without asking anything is what the last hold found, which is
    // the number that matters when someone says saving did not work.
    if (sciSeen == 0) {
        return SCILocalized(@"dl_diag_none");
    }
    return [NSString stringWithFormat:SCILocalized(@"dl_diag_found"),
            (long)(sciSeen - sciUnplayable - sciNoURL), (long)sciSeen];
}

/// The best audio available, for pairing with a video-only format.
+ (SCIYTFormat *)bestAudio:(NSArray<SCIYTFormat *> *)formats {
    SCIYTFormat *best = nil;
    for (SCIYTFormat *format in formats) {
        if (format.isVideo) continue;
        if (!best || format.bitrate > best.bitrate) best = format;
    }
    return best;
}

#pragma mark - Choosing

+ (void)presentFrom:(UIViewController *)presenter {
    if (!presenter) return;

    // The activated video first, and the last MLVideo only as a fallback.
    //
    // They are not the same thing: MLVideo objects are created for videos the app is
    // preloading as well as the one on screen. A report showed SponsorBlock working on
    // one id while this asked YouTube about another, which is a download that could only
    // ever fail -- and failed with a message blaming the video for being private.
    NSString *videoID = [SCIYTDiagnostics activeVideoID] ?: [SCIYTDiagnostics lastVideoID];
    if (!videoID.length) {
        [self showMessage:SCILocalized(@"dl_why_no_data") from:presenter];
        return;
    }

    // There is a network round trip in front of the sheet now, so something has to say
    // so. Asking YouTube takes a moment, and a hold that appears to do nothing reads as
    // a broken gesture — which is exactly how 0.6.0's looked while it was silently
    // losing to YouTube's own recognisers.
    UIAlertController *waiting =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:SCILocalized(@"dl_asking")
                                     preferredStyle:UIAlertControllerStyleAlert];

    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^done)(void (^)(void)) = ^(void (^next)(void)) {
        void (^close)(void) = ^{
            [waiting dismissViewControllerAnimated:YES completion:next];
        };
        if (shown) close(); else pending = close;
    };

    [presenter presentViewController:waiting animated:YES completion:^{
        shown = YES;
        if (pending) { void (^queued)(void) = pending; pending = nil; queued(); }
    }];

    [SCIYTStreamAPI streamingDataForVideo:videoID
                               completion:^(NSDictionary *streamingData, NSString *failure) {
        NSArray<SCIYTFormat *> *formats = [self formatsFromStreamingData:streamingData];

        done(^{
            if (!formats.count) {
                // The server's own sentence when it gave one -- private, age-gated,
                // blocked here -- and our tally when it did not.
                [self showMessage:(failure ?: [self refusalReason]) from:presenter];
                return;
            }
            [self presentSheetFor:formats from:presenter];
        });
    }];
}

+ (void)presentSheetFor:(NSArray<SCIYTFormat *> *)formats from:(UIViewController *)presenter {

    // Highest first, and one entry per quality: three renditions of 1080p differ only
    // in a codec the user did not ask about.
    NSMutableArray<SCIYTFormat *> *videos = [NSMutableArray array];
    NSMutableSet<NSString *> *labels = [NSMutableSet set];

    NSArray<SCIYTFormat *> *sorted = [formats sortedArrayUsingComparator:^NSComparisonResult(SCIYTFormat *a, SCIYTFormat *b) {
        if (a.height != b.height) return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
        return a.bitrate > b.bitrate ? NSOrderedAscending : NSOrderedDescending;
    }];

    for (SCIYTFormat *format in sorted) {
        if (!format.isVideo) continue;

        NSString *label = format.qualityLabel.length ? format.qualityLabel
                        : [NSString stringWithFormat:@"%ldp", (long)format.height];
        if ([labels containsObject:label]) continue;

        [labels addObject:label];
        [videos addObject:format];
    }

    // No video worth offering, but the sound may still be there -- a track people
    // actually want on its own, and 0.5.0 refused the whole thing at this point.
    if (!videos.count && ![self bestAudio:formats]) {
        [self showMessage:[self refusalReason] from:presenter];
        return;
    }

    SCIYTFormat *audio = [self bestAudio:formats];

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_choose_quality")
                                            message:[SCIYTDiagnostics lastVideoTitle]
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (SCIYTFormat *video in videos) {
        NSString *label = video.qualityLabel.length ? video.qualityLabel
                        : [NSString stringWithFormat:@"%ldp", (long)video.height];

        // Says plainly when a quality needs the audio fetched separately, because that
        // one takes longer and the wait should not be a surprise.
        if (!video.hasAudio && audio) {
            label = [label stringByAppendingString:SCILocalized(@"dl_with_audio")];
        } else if (!video.hasAudio && !audio) {
            continue;   // video-only with nothing to pair: silent file, not worth offering
        }

        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self startVideo:video audio:(video.hasAudio ? nil : audio) from:presenter];
        }]];
    }

    // Sound on its own. Kept last so it never sits between two qualities, and offered
    // whenever there is an audio stream -- for music and podcasts it is the point, not a
    // fallback.
    if (audio) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dl_audio_only")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self startAudioOnly:audio from:presenter];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // An unanchored action sheet is fatal on iPad.
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);

    [presenter presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Fetching

/// A request that YouTube's CDN will serve.
///
/// The headers are not decoration: a bare request for one of these links is refused.
/// Identity encoding matters too — a gzipped video is not a video.
+ (NSURLRequest *)requestForURL:(NSURL *)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"https://www.youtube.com" forHTTPHeaderField:@"Origin"];
    [request setValue:@"https://www.youtube.com/" forHTTPHeaderField:@"Referer"];
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
    request.timeoutInterval = 60;
    return request;
}

/// Downloads one file to a temporary path.
///
/// No progress reporting, deliberately. A percentage would need an NSURLSession
/// delegate object living beyond this call, and the alert it fed would still not be
/// cancellable without more machinery again. Two transfers of a few tens of megabytes
/// finish quickly enough that "working…" is honest, and it is one moving part instead
/// of four.
+ (void)fetch:(NSString *)urlString
    extension:(NSString *)extension
   completion:(void (^)(NSURL *file, NSError *error))completion {

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"AlbrhiYT" code:1 userInfo:nil]);
        return;
    }

    NSURLSessionDownloadTask *task =
        [[NSURLSession sharedSession] downloadTaskWithRequest:[self requestForURL:url]
                                            completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!location || error) {
            completion(nil, error);
            return;
        }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)response statusCode] : 200;

        if (status != 200 && status != 206) {
            SCILogV(@"download: server said %ld", (long)status);
            completion(nil, [NSError errorWithDomain:@"AlbrhiYT" code:status userInfo:nil]);
            return;
        }

        // Moved out of the session's temporary directory, which is emptied the moment
        // this handler returns.
        NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension];
        NSURL *destination = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&moveError];

        completion(moveError ? nil : destination, moveError);
    }];

    [task resume];
}

#pragma mark - Merging

/// Puts a video track and an audio track into one file.
///
/// AVMutableComposition rather than a remux library: both streams are already H.264 and
/// AAC in MP4 containers — that is what the itag filter guaranteed — so nothing needs
/// re-encoding and the export is a passthrough copy. It is why this feature does not
/// carry FFmpeg.
+ (void)mergeVideo:(NSURL *)videoURL
             audio:(NSURL *)audioURL
        completion:(void (^)(NSURL *file, NSError *error))completion {

    AVMutableComposition *composition = [AVMutableComposition composition];
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];

    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetTrack *audioTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;

    if (!videoTrack) {
        completion(nil, [NSError errorWithDomain:@"AlbrhiYT" code:2 userInfo:nil]);
        return;
    }

    // Each insert gets its own error and its own check. Sharing one NSError* meant the
    // second call overwrote whatever the first reported, and neither return value was
    // read at all -- so a failed video insert exported an empty composition and the
    // result was saved as though it had worked.
    NSError *videoError = nil;
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);

    AVMutableCompositionTrack *video =
        [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                 preferredTrackID:kCMPersistentTrackID_Invalid];

    if (![video insertTimeRange:range ofTrack:videoTrack atTime:kCMTimeZero error:&videoError]) {
        SCILogV(@"download: the picture would not go in — %@", videoError.localizedDescription);
        completion(nil, videoError);
        return;
    }

    BOOL soundIsIn = NO;

    if (audioTrack) {
        NSError *audioError = nil;
        AVMutableCompositionTrack *audio =
            [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                     preferredTrackID:kCMPersistentTrackID_Invalid];

        // The audio may run a fraction longer or shorter than the picture; the shorter
        // of the two is the safe range, and a mismatch here is an export failure.
        CMTime length = CMTimeMinimum(videoAsset.duration, audioAsset.duration);
        soundIsIn = [audio insertTimeRange:CMTimeRangeMake(kCMTimeZero, length)
                                   ofTrack:audioTrack
                                    atTime:kCMTimeZero
                                     error:&audioError];

        if (!soundIsIn) {
            SCILogV(@"download: the sound would not go in — %@", audioError.localizedDescription);
        }
    }

    NSURL *output = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];

    AVAssetExportSession *export =
        [[AVAssetExportSession alloc] initWithAsset:composition
                                         presetName:AVAssetExportPresetPassthrough];
    export.outputURL = output;
    export.outputFileType = AVFileTypeMPEG4;

    [export exportAsynchronouslyWithCompletionHandler:^{
        if (export.status == AVAssetExportSessionStatusCompleted) {
            completion(soundIsIn ? output : nil, nil);
        } else {
            SCILogV(@"download: export failed — %@", export.error.localizedDescription);
            completion(nil, export.error);
        }
    }];
}

#pragma mark - The run

/// Deletes a temporary file, if there is one.
///
/// 0.5.0 removed only the file it handed to Photos, so a merged save left both inputs
/// behind -- two files of tens of megabytes each, per download, sitting in the app's
/// temporary directory until iOS decided to reclaim it.
+ (void)discard:(NSURL *)file {
    if (!file) return;
    [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
}

+ (void)startVideo:(SCIYTFormat *)video audio:(SCIYTFormat *)audio from:(UIViewController *)presenter {
    UIAlertController *progress =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_saving")
                                            message:SCILocalized(@"dl_working")
                                     preferredStyle:UIAlertControllerStyleAlert];

    // Whether the alert has finished appearing.
    //
    // Dismissing a controller that is still animating in is ignored by UIKit, and its
    // completion block never runs -- which left an alert with no buttons on screen and
    // no way out but force-quitting YouTube. It was not a race in theory either: -fetch:
    // calls back synchronously when the URL will not parse, on the same runloop turn
    // that started the presentation.
    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *detail) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^close)(void) = ^{
                [progress dismissViewControllerAnimated:YES completion:^{
                    // detail is used on success too. 0.5.0 built the "saved without
                    // sound" sentence and then threw it away here, so a silent file was
                    // always reported as a clean save.
                    [self showMessage:(detail.length ? detail : SCILocalized(@"dl_saved"))
                                 from:presenter];
                }];
            };

            if (shown) {
                close();
            } else {
                // Held until the presentation finishes, rather than fired into it.
                pending = close;
            }
        });
    };

    [presenter presentViewController:progress animated:YES completion:^{
        shown = YES;
        if (pending) {
            void (^queued)(void) = pending;
            pending = nil;
            queued();
        }
    }];

    [self fetch:video.urlString extension:@"mp4" completion:^(NSURL *videoFile, NSError *error) {
        if (!videoFile) {
            finish(NO, SCILocalized(@"dl_failed"));
            return;
        }

        // Muxed already, or no audio to pair: save what arrived.
        if (!audio) {
            [self saveToPhotos:videoFile completion:^(BOOL ok, NSString *detail) {
                finish(ok, ok ? nil : detail);
            }];
            return;
        }

        [self fetch:audio.urlString extension:@"m4a" completion:^(NSURL *audioFile, NSError *audioError) {
            if (!audioFile) {
                // The picture arrived and the sound did not. Saving the silent file is
                // better than saving nothing, and the message now actually says so.
                [self saveToPhotos:videoFile completion:^(BOOL ok, NSString *detail) {
                    finish(ok, ok ? SCILocalized(@"dl_saved_silent") : detail);
                }];
                return;
            }

            [self mergeVideo:videoFile audio:audioFile completion:^(NSURL *merged, NSError *mergeError) {
                // Both inputs go, whichever way the merge went. saveToPhotos only ever
                // removes the one file it was handed.
                [self discard:audioFile];

                if (merged) {
                    [self discard:videoFile];
                    [self saveToPhotos:merged completion:^(BOOL ok, NSString *detail) {
                        finish(ok, ok ? nil : detail);
                    }];
                } else {
                    // The merge failed, so what gets saved is the picture on its own.
                    // Saying "saved" here would be a lie the user only discovers on
                    // playback.
                    [self saveToPhotos:videoFile completion:^(BOOL ok, NSString *detail) {
                        finish(ok, ok ? SCILocalized(@"dl_saved_silent") : detail);
                    }];
                }
            }];
        }];
    }];
}

///
/// Sound on its own, saved where sound can actually live.
///
/// Not Photos: it takes video and images, and an .m4a handed to it is refused. So the
/// file goes to the app's own Documents folder and the share sheet opens on it, which
/// puts it into Files, Music, a message, or anywhere else in one step.
///
/// Documents rather than the temporary directory, because a file the user chose to keep
/// must survive iOS reclaiming scratch space -- and because it is where the download
/// centre will read from next.
+ (void)startAudioOnly:(SCIYTFormat *)audio from:(UIViewController *)presenter {
    UIAlertController *progress =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_saving")
                                            message:SCILocalized(@"dl_working")
                                     preferredStyle:UIAlertControllerStyleAlert];

    __block BOOL shown = NO;
    __block void (^pending)(void) = nil;

    void (^finish)(NSURL *, NSString *) = ^(NSURL *file, NSString *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^close)(void) = ^{
                [progress dismissViewControllerAnimated:YES completion:^{
                    if (!file) {
                        [self showMessage:(failure ?: SCILocalized(@"dl_failed")) from:presenter];
                        return;
                    }
                    [self shareFile:file from:presenter];
                }];
            };
            if (shown) close(); else pending = close;
        });
    };

    [presenter presentViewController:progress animated:YES completion:^{
        shown = YES;
        if (pending) { void (^queued)(void) = pending; pending = nil; queued(); }
    }];

    [self fetch:audio.urlString extension:@"m4a" completion:^(NSURL *file, NSError *error) {
        if (!file) {
            finish(nil, SCILocalized(@"dl_failed"));
            return;
        }

        NSString *title = [SCIYTDiagnostics lastVideoTitle] ?: @"audio";
        NSURL *kept = [self keep:file named:title extension:@"m4a"];
        finish(kept ?: file, nil);
    }];
}

/// Moves a finished file into Documents under a readable name.
+ (NSURL *)keep:(NSURL *)file named:(NSString *)title extension:(NSString *)extension {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!documents) return nil;

    NSString *folder = [documents stringByAppendingPathComponent:@"Albrhi"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    // Anything a file system objects to, replaced. A YouTube title can contain slashes,
    // colons and newlines, and a path built from one unfiltered simply fails to write.
    // The control characters are added separately rather than written into the literal:
    // Objective-C has no multi-line string, and this project has corrupted source files
    // three times by putting an escape sequence through a shell heredoc. Once more here.
    NSMutableCharacterSet *illegal =
        [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [illegal formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
    [illegal formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    NSString *safe = [[title componentsSeparatedByCharactersInSet:illegal]
        componentsJoinedByString:@" "];

    safe = [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (safe.length > 80) safe = [safe substringToIndex:80];
    if (!safe.length) safe = @"audio";

    NSString *path = [folder stringByAppendingPathComponent:
        [safe stringByAppendingPathExtension:extension]];

    // A second download of the same track must not fail on the name already being taken.
    NSUInteger attempt = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [folder stringByAppendingPathComponent:
            [[NSString stringWithFormat:@"%@ (%lu)", safe, (unsigned long)attempt++]
                stringByAppendingPathExtension:extension]];
    }

    NSError *error = nil;
    NSURL *destination = [NSURL fileURLWithPath:path];
    if (![[NSFileManager defaultManager] moveItemAtURL:file toURL:destination error:&error]) {
        SCILogV(@"download: could not keep the file — %@", error.localizedDescription);
        return nil;
    }
    return destination;
}

+ (void)shareFile:(NSURL *)file from:(UIViewController *)presenter {
    UIActivityViewController *share =
        [[UIActivityViewController alloc] initWithActivityItems:@[file]
                                          applicationActivities:nil];

    // An unanchored sheet is fatal on iPad, the same as the quality one.
    share.popoverPresentationController.sourceView = presenter.view;
    share.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);

    [presenter presentViewController:share animated:YES completion:nil];
}

+ (void)saveToPhotos:(NSURL *)file completion:(void (^)(BOOL ok, NSString *detail))completion {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            completion(NO, SCILocalized(@"dl_no_permission"));
            return;
        }

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:file];
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) SCILogV(@"download: Photos refused it — %@", error.localizedDescription);

            // The temporary file has served its purpose either way.
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];

            completion(success, success ? nil : SCILocalized(@"dl_failed"));
        }];
    }];
}

+ (void)showMessage:(NSString *)message from:(UIViewController *)presenter {
    if (!message.length) return;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@end
