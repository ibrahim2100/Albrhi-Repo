#import "SCIYTHLS.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import <AVFoundation/AVFoundation.h>

@implementation SCIHLSVariant

- (NSString *)label {
    NSString *size = self.height ? [NSString stringWithFormat:@"%ldp", (long)self.height]
                                 : SCILocalized(@"dl_unknown_quality");

    // The codec matters to the user only when it is the reason a quality is missing, so
    // it is not spelled out here -- anything that reaches this point is playable.
    return size;
}

@end


/// Only what iOS can put in an .mp4 without re-encoding.
///
/// The same rule the itag list follows on the other path, applied to what a playlist
/// declares instead: avc1 is H.264, mp4a is AAC. A variant in VP9 or Opus would download
/// perfectly and then be a file that will not play, which is worse than not offering it.
static BOOL SCICodecsArePlayable(NSString *codecs) {
    if (!codecs.length) return YES;   // unstated is not a reason to refuse

    NSString *lower = codecs.lowercaseString;
    if ([lower containsString:@"vp9"] || [lower containsString:@"vp09"]) return NO;
    if ([lower containsString:@"av01"]) return NO;
    if ([lower containsString:@"opus"]) return NO;
    return YES;
}

/// The value of one attribute in an EXT-X line.
static NSString *SCIAttribute(NSString *line, NSString *name) {
    NSRange found = [line rangeOfString:[name stringByAppendingString:@"="]];
    if (found.location == NSNotFound) return nil;

    NSString *rest = [line substringFromIndex:NSMaxRange(found)];
    if ([rest hasPrefix:@"\""]) {
        rest = [rest substringFromIndex:1];
        NSRange close = [rest rangeOfString:@"\""];
        return close.location == NSNotFound ? rest : [rest substringToIndex:close.location];
    }

    NSRange comma = [rest rangeOfString:@","];
    return comma.location == NSNotFound ? rest : [rest substringToIndex:comma.location];
}


@implementation SCIYTHLS

+ (NSURLSession *)session {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config =
            [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 20;
        config.timeoutIntervalForResource = 60 * 30;
        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

+ (void)fetchText:(NSString *)address completion:(void (^)(NSString *, NSString *))completion {
    NSURL *url = [NSURL URLWithString:address];
    if (!url) {
        completion(nil, SCILocalized(@"dl_failed"));
        return;
    }

    [[[self session] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            completion(nil, error.localizedDescription ?: SCILocalized(@"dl_failed"));
            return;
        }

        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? [(NSHTTPURLResponse *)response statusCode] : 200;
        if (status != 200) {
            completion(nil, [NSString stringWithFormat:@"HTTP %ld", (long)status]);
            return;
        }

        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        completion(text, text.length ? nil : SCILocalized(@"dl_failed"));
    }] resume];
}

// MARK: - The master playlist

+ (void)variantsForManifest:(NSString *)manifestURL
                 completion:(void (^)(NSArray<SCIHLSVariant *> *, NSString *))completion {
    if (!manifestURL.length) {
        completion(@[], SCILocalized(@"dl_hls_none"));
        return;
    }

    [self fetchText:manifestURL completion:^(NSString *text, NSString *failure) {
        if (!text) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(@[], failure); });
            return;
        }

        NSMutableArray<SCIHLSVariant *> *variants = [NSMutableArray array];
        NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:
            [NSCharacterSet newlineCharacterSet]];

        // An EXT-X-STREAM-INF line describes the next non-comment line, which is the URL.
        for (NSUInteger i = 0; i < lines.count; i++) {
            NSString *line = [lines[i] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if (![line hasPrefix:@"#EXT-X-STREAM-INF"]) continue;

            NSString *address = nil;
            for (NSUInteger j = i + 1; j < lines.count; j++) {
                NSString *candidate = [lines[j] stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]];
                if (!candidate.length || [candidate hasPrefix:@"#"]) continue;
                address = candidate;
                break;
            }
            if (!address.length) continue;

            NSString *codecs = SCIAttribute(line, @"CODECS");
            if (!SCICodecsArePlayable(codecs)) continue;

            SCIHLSVariant *variant = [[SCIHLSVariant alloc] init];
            variant.playlistURL = [[NSURL URLWithString:address
                                          relativeToURL:[NSURL URLWithString:manifestURL]]
                                   absoluteString] ?: address;
            variant.codecs = codecs;
            variant.bandwidth = [SCIAttribute(line, @"BANDWIDTH") longLongValue];

            NSString *resolution = SCIAttribute(line, @"RESOLUTION");
            NSArray<NSString *> *parts = [resolution componentsSeparatedByString:@"x"];
            if (parts.count == 2) {
                variant.width = [parts[0] integerValue];
                variant.height = [parts[1] integerValue];
            }

            [variants addObject:variant];
        }

        [variants sortUsingComparator:^NSComparisonResult(SCIHLSVariant *a, SCIHLSVariant *b) {
            if (a.height != b.height) return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
            return a.bandwidth > b.bandwidth ? NSOrderedAscending : NSOrderedDescending;
        }];

        SCILogV(@"hls: %lu playable variants", (unsigned long)variants.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(variants, variants.count ? nil : SCILocalized(@"dl_hls_no_variants"));
        });
    }];
}

// MARK: - One quality

+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double))progress
             completion:(void (^)(NSURL *, NSString *))completion {

    void (^finish)(NSURL *, NSString *) = ^(NSURL *file, NSString *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(file, failure); });
    };

    [self fetchText:variant.playlistURL completion:^(NSString *text, NSString *failure) {
        if (!text) {
            finish(nil, failure);
            return;
        }

        NSMutableArray<NSString *> *segments = [NSMutableArray array];
        NSString *initSegment = nil;
        NSURL *base = [NSURL URLWithString:variant.playlistURL];

        for (NSString *raw in [text componentsSeparatedByCharactersInSet:
                               [NSCharacterSet newlineCharacterSet]]) {
            NSString *line = [raw stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if (!line.length) continue;

            if ([line hasPrefix:@"#EXT-X-MAP"]) {
                // Fragmented MP4. The initialisation segment carries the headers every
                // following part needs, and its presence is what decides whether joining
                // the parts produces something readable at all.
                NSString *uri = SCIAttribute(line, @"URI");
                if (uri.length) {
                    initSegment = [[NSURL URLWithString:uri relativeToURL:base] absoluteString];
                }
                continue;
            }

            if ([line hasPrefix:@"#"]) continue;

            NSString *resolved = [[NSURL URLWithString:line relativeToURL:base] absoluteString];
            if (resolved.length) [segments addObject:resolved];
        }

        if (!segments.count) {
            finish(nil, SCILocalized(@"dl_hls_no_segments"));
            return;
        }

        // Said plainly rather than attempted and left half-done. Joined MPEG-TS parts are
        // not a file AVFoundation will export, and producing a broken video would be
        // worse than saying which format this build serves.
        if (!initSegment) {
            SCILogV(@"hls: no EXT-X-MAP, segments are probably MPEG-TS");
        }

        SCILogV(@"hls: %lu segments%@", (unsigned long)segments.count,
                initSegment ? @", fragmented MP4" : @", no init segment");

        [self joinSegments:segments
               initSegment:initSegment
                  progress:progress
                completion:finish];
    }];
}

/// Fetches every part in order and appends it to one file.
///
/// Sequentially, and to a file handle rather than into memory: the parts of a 1080p video
/// come to a couple of hundred megabytes, and a phone should not be asked to hold that
/// twice. Sequential also keeps the order right without any reassembly step, which is the
/// entire reason this produces a playable file at the end.
+ (void)joinSegments:(NSArray<NSString *> *)segments
         initSegment:(NSString *)initSegment
            progress:(void (^)(double))progress
          completion:(void (^)(NSURL *, NSString *))completion {

    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"];
    NSURL *joined = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:name]];

    [[NSFileManager defaultManager] createFileAtPath:joined.path contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:joined error:nil];
    if (!handle) {
        completion(nil, SCILocalized(@"dl_failed"));
        return;
    }

    NSMutableArray<NSString *> *queue = [NSMutableArray array];
    if (initSegment) [queue addObject:initSegment];
    [queue addObjectsFromArray:segments];

    NSUInteger total = queue.count;
    __block NSUInteger done = 0;

    // A recursive block rather than a loop, because each part has to finish before the
    // next is asked for -- appending out of order would produce a file that plays as
    // nonsense.
    __block void (^next)(void) = nil;
    __weak typeof(self) weakSelf = self;

    next = ^{
        if (!queue.count) {
            [handle closeFile];
            [weakSelf exportJoined:joined completion:completion];
            return;
        }

        NSString *address = queue.firstObject;
        [queue removeObjectAtIndex:0];

        [[[self session] dataTaskWithURL:[NSURL URLWithString:address]
                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!data || error) {
                [handle closeFile];
                [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
                completion(nil, error.localizedDescription ?: SCILocalized(@"dl_failed"));
                return;
            }

            @try {
                [handle writeData:data];
            } @catch (NSException *exception) {
                [handle closeFile];
                [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
                completion(nil, exception.reason ?: SCILocalized(@"dl_failed"));
                return;
            }

            done++;
            if (progress) {
                double fraction = (double)done / (double)total;
                dispatch_async(dispatch_get_main_queue(), ^{ progress(fraction); });
            }

            next();
        }] resume];
    };

    next();
}

/// Rewrites the joined parts as a normal .mp4.
///
/// A passthrough export: both tracks are already H.264 and AAC, which the variant filter
/// guaranteed, so nothing is re-encoded and this is a remux. It is also the step that
/// says whether the joining worked -- an unreadable file fails here rather than arriving
/// in Photos as something that will not play.
+ (void)exportJoined:(NSURL *)joined completion:(void (^)(NSURL *, NSString *))completion {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:joined options:nil];

    if (![asset tracksWithMediaType:AVMediaTypeVideo].count) {
        [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
        completion(nil, SCILocalized(@"dl_hls_unreadable"));
        return;
    }

    NSURL *output = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];

    AVAssetExportSession *export =
        [[AVAssetExportSession alloc] initWithAsset:asset
                                         presetName:AVAssetExportPresetPassthrough];
    export.outputURL = output;
    export.outputFileType = AVFileTypeMPEG4;

    [export exportAsynchronouslyWithCompletionHandler:^{
        [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];

        if (export.status == AVAssetExportSessionStatusCompleted) {
            completion(output, nil);
        } else {
            SCILogV(@"hls: export failed — %@", export.error.localizedDescription);
            completion(nil, export.error.localizedDescription ?: SCILocalized(@"dl_hls_unreadable"));
        }
    }];
}

@end
