#import "SCIYTDownload.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
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

/// A zero-argument getter's value, boxed, or nil.
///
/// KVC rather than -performSelector:, because these return a mix of objects, integers
/// and doubles and KVC boxes all three without the caller having to know which.
static id SCIValue(id object, NSString *key) {
    if (!object || !key.length) return nil;
    @try {
        if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *SCIString(id object, NSString *key) {
    id value = SCIValue(object, key);
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSURL class]]) return [(NSURL *)value absoluteString];
    if (!value) return nil;

    // MIMEType comes back as a wrapper object rather than a string on this build.
    for (NSString *inner in @[@"stringValue", @"string", @"type", @"name"]) {
        id text = SCIValue(value, inner);
        if ([text isKindOfClass:[NSString class]] && [text length]) return text;
    }
    return nil;
}

static NSInteger SCIInteger(id object, NSString *key) {
    id value = SCIValue(object, key);
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

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
/// A fetchable link for a stream.
///
/// The stream's own -URL answers with a query fragment ("?cpn=…") and nothing else on
/// this build — measured, and the reason an earlier diagnostics run looked like there
/// were no links at all. The real one hangs off a nested formatStream. That is the
/// single most valuable thing taken from YouMod: it would have cost several rounds on
/// a device to find.
///
static NSString *SCIURLForStream(id stream) {
    id formatStream = SCIValue(stream, @"formatStream");

    for (id source in @[stream, formatStream ?: [NSNull null]]) {
        if ([source isKindOfClass:[NSNull class]]) continue;

        for (NSString *key in @[@"URL", @"url", @"urlString", @"URLString"]) {
            NSString *text = SCIString(source, key);

            // A URL, not the fragment the outer stream answers with.
            if ([text hasPrefix:@"http"]) return text;
        }
    }
    return nil;
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
static NSString *sciRefusedItags = nil;

+ (NSArray<SCIYTFormat *> *)formats {
    id streamingData = [SCIYTDiagnostics lastStreamingData];

    sciSeen = 0;
    sciNoURL = 0;
    sciUnplayable = 0;
    sciRefusedItags = nil;

    if (!streamingData) return @[];

    NSMutableArray<SCIYTFormat *> *out = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];
    NSMutableOrderedSet<NSNumber *> *refused = [NSMutableOrderedSet orderedSet];

    // Both names, because which one is populated varies and asking for the other costs
    // a message send that returns nil.
    for (NSString *key in @[@"adaptiveStreams", @"adaptiveFormatsArray", @"formats"]) {
        id list = SCIValue(streamingData, key);
        if (![list isKindOfClass:[NSArray class]]) continue;

        for (id stream in (NSArray *)list) {
            NSInteger itag = SCIInteger(stream, @"itag");
            if (!itag) itag = SCIInteger(SCIValue(stream, @"formatStream"), @"itag");
            if (!itag || [seen containsObject:@(itag)]) continue;

            sciSeen++;

            BOOL isVideo = [SCIPlayableVideoItags() containsObject:@(itag)];
            BOOL isAudio = [SCIPlayableAudioItags() containsObject:@(itag)];
            if (!isVideo && !isAudio) {
                // A codec iOS will not play. The itag is kept rather than just counted:
                // it names the codec exactly, which is what decides whether the answer
                // is "widen this list" or "this build only streams".
                sciUnplayable++;
                [refused addObject:@(itag)];
                continue;
            }

            NSString *url = SCIPreparedURL(SCIURLForStream(stream));
            if (!url.length) {
                sciNoURL++;
                continue;
            }

            [seen addObject:@(itag)];

            SCIYTFormat *format = [[SCIYTFormat alloc] init];
            format.itag = itag;
            format.urlString = url;
            format.isVideo = isVideo;
            format.hasAudio = isAudio || SCIItagIsMuxed(itag);
            format.height = SCIInteger(stream, @"height");
            format.fps = SCIInteger(stream, @"fps");
            format.bitrate = (long long)SCIInteger(stream, @"bitrate");
            format.qualityLabel = SCIString(stream, @"qualityLabel");

            [out addObject:format];
        }
    }

    if (refused.count) {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (NSNumber *itag in [refused.array subarrayWithRange:
                NSMakeRange(0, MIN(refused.count, (NSUInteger)8))]) {
            [names addObject:itag.stringValue];
        }
        sciRefusedItags = [names componentsJoinedByString:@", "];
    }

    SCILogV(@"download: %ld seen, %ld unplayable, %ld without a link, %lu usable",
            (long)sciSeen, (long)sciUnplayable, (long)sciNoURL, (unsigned long)out.count);

    return out;
}

/// The sentence shown when nothing can be saved, naming which of the three walls it hit.
+ (NSString *)refusalReason {
    if (![SCIYTDiagnostics lastStreamingData]) {
        return SCILocalized(@"dl_why_no_data");
    }
    if (sciSeen == 0) {
        return SCILocalized(@"dl_why_no_formats");
    }
    if (sciNoURL > 0 && sciUnplayable == 0) {
        return [NSString stringWithFormat:SCILocalized(@"dl_why_no_urls"), (long)sciNoURL];
    }
    if (sciUnplayable > 0) {
        return [NSString stringWithFormat:SCILocalized(@"dl_why_unplayable"),
                (long)sciUnplayable, sciRefusedItags ?: @"?"];
    }
    return SCILocalized(@"dl_why_unknown");
}

+ (NSString *)diagnosticsSummary {
    NSArray<SCIYTFormat *> *formats = [self formats];
    if (!formats.count) {
        return SCILocalized(@"dl_diag_none");
    }

    NSInteger video = 0, audio = 0;
    for (SCIYTFormat *format in formats) {
        if (format.isVideo) video++; else audio++;
    }

    return [NSString stringWithFormat:SCILocalized(@"dl_diag_found"),
            (long)video, (long)audio];
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

    NSArray<SCIYTFormat *> *formats = [self formats];

    if (!formats.count) {
        // Which of the three walls, in one sentence, instead of "nothing to download"
        // for all of them.
        [self showMessage:[self refusalReason] from:presenter];
        return;
    }

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
