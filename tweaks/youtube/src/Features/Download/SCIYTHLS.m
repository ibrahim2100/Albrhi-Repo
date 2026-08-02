#import "SCIYTHLS.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
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
        BOOL byteRanged = NO;
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

            if ([line hasPrefix:@"#EXT-X-BYTERANGE"]) {
                // Every "segment" is a slice of one file rather than a file of its own.
                //
                // This line was skipped along with every other tag, which is why 0.10.1
                // downloaded something unusable: the parser saw the same URL repeated
                // once per slice and fetched the *whole file* each time, then joined the
                // copies end to end. Hundreds of megabytes, and of course nothing could
                // read it.
                byteRanged = YES;
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

        // What the playlist actually turned out to be, in the report. 0.10.1 said only
        // that the pieces would not join, which is a symptom and names none of the three
        // shapes a playlist can have.
        NSCountedSet *distinct = [NSCountedSet setWithArray:segments];
        [SCIYTDiagnostics recordStreamAttempt:
            [NSString stringWithFormat:@"hls: %lu entries, %lu distinct URLs%@%@",
             (unsigned long)segments.count, (unsigned long)distinct.count,
             byteRanged ? @", byte ranges" : @"",
             initSegment ? @", fMP4 init" : @", no init"]];

        // One file addressed by ranges: the whole of it is the media, so it is fetched
        // once instead of once per slice. This is both the fix for the previous release
        // and the simplest possible case -- a complete file, already muxed, no joining.
        if (distinct.count == 1 && segments.count > 1) {
            SCILogV(@"hls: %lu ranges over one file — fetching it whole",
                    (unsigned long)segments.count);
            [self joinSegments:@[segments.firstObject]
                   initSegment:nil
                      progress:progress
                    completion:finish];
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

    // A method calling itself, not a block calling itself.
    //
    // The obvious way to write this is a __block block that invokes its own variable at
    // the end, and ARC rejects it outright: the block captures itself strongly and can
    // never be released. The usual dodge is a weak copy of it, which trades a leak for a
    // block that may be gone by the time the next part arrives.
    //
    // A method has neither problem. The remaining work is an argument rather than a
    // capture, so there is nothing to retain and nothing to keep alive.
    [self writeNext:queue
             handle:handle
             joined:joined
              total:queue.count
               done:0
           progress:progress
         completion:completion];
}

+ (void)writeNext:(NSMutableArray<NSString *> *)queue
           handle:(NSFileHandle *)handle
           joined:(NSURL *)joined
            total:(NSUInteger)total
             done:(NSUInteger)done
         progress:(void (^)(double))progress
       completion:(void (^)(NSURL *, NSString *))completion {

    if (!queue.count) {
        [handle closeFile];
        [self exportJoined:joined completion:completion];
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

        NSUInteger written = done + 1;
        if (progress && total) {
            double fraction = (double)written / (double)total;
            dispatch_async(dispatch_get_main_queue(), ^{ progress(fraction); });
        }

        [self writeNext:queue
                 handle:handle
                 joined:joined
                  total:total
                   done:written
               progress:progress
             completion:completion];
    }] resume];
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
