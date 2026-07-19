#import "SCIMediaDownloader.h"
#import "Download.h"
#import "Queue/SCIDownloadQueue.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Settings/SCIDiagnosticsViewController.h"

@implementation SCIMediaDownloader

// MARK: - Qualities

+ (NSArray<NSDictionary *> *)qualitiesForVideo:(IGVideo *)video {
    if (!video) return @[];

    // Read IGAPIVideoVersion directly rather than through SCIUtils, because the
    // bitrate matters: Instagram commonly ships several renditions at the *same*
    // resolution and different bandwidths. Collapsing those into one — which an
    // earlier version did, by labelling on resolution alone — left the picker
    // with a single entry and nothing to offer.
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    NSInteger rawCount = 0;

    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];

            if ([versions respondsToSelector:@selector(count)]) {
                rawCount = (NSInteger)[versions count];
                [SCIDiagnostics recordRawVersionCount:rawCount];
            }

            for (id version in versions) {
                NSString *urlString = [SCIUtils urlStringFromVersion:version];
                if (![urlString length]) continue;

                long long w = [SCIUtils qualityValueFrom:version key:@"width"];
                long long h = [SCIUtils qualityValueFrom:version key:@"height"];
                long long bandwidth = [SCIUtils qualityValueFrom:version key:@"bandwidth"];

                // Keep the raw string and resolve to NSURL only when downloading.
                // Building the URL here dropped renditions silently: CDN links carry
                // characters that make +URLWithString: return nil, and a nil url was
                // then discarded by deduplication — three renditions became one.
                [out addObject:@{
                    @"label": [self labelForWidth:w height:h bandwidth:bandwidth],
                    @"urlString": urlString,
                    @"area": @(w * h),
                    @"bandwidth": @(bandwidth)
                }];
            }
        }
    } @catch (__unused id e) {}

    // Best first: resolution, then bitrate.
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSComparisonResult byArea = [b[@"area"] compare:a[@"area"]];
        if (byArea != NSOrderedSame) return byArea;

        return [b[@"bandwidth"] compare:a[@"bandwidth"]];
    }];

    NSInteger parsedCount = (NSInteger)out.count;

    out = [[self deduplicated:out] mutableCopy];

    [SCIDiagnostics recordQualityBreakdownRaw:rawCount
                                       parsed:parsedCount
                                      deduped:(NSInteger)out.count
                                       labels:[[out valueForKey:@"label"] componentsJoinedByString:@" | "]];

    if (out.count > 1) return out;

    // videoVersions gave a single progressive rendition (common on IG 410+). The
    // real resolution ladder — 1080p and friends — lives in the DASH manifest.
    NSArray<NSDictionary *> *dash = [self deduplicated:[self qualitiesFromDashForVideo:video]];
    if (dash.count > out.count) out = [dash mutableCopy];
    if (out.count > 1) return out;

    // Fall back to the generic helper if the direct read found nothing usable.
    NSArray<NSDictionary *> *helperVersions = [self deduplicated:[self normalised:[SCIUtils availableVideoQualitiesForVideo:video]]];
    if (helperVersions.count > out.count) out = [helperVersions mutableCopy];
    if (out.count > 1) return out;

    // Older builds expose an ascending array of {url, width, height} dictionaries.
    @try {
        if ([video respondsToSelector:@selector(sortedVideoURLsBySize)]) {
            NSArray<NSDictionary *> *sorted = [video sortedVideoURLsBySize];

            if ([sorted isKindOfClass:[NSArray class]]) {
                NSMutableArray<NSDictionary *> *legacy = [NSMutableArray array];

                for (NSDictionary *entry in sorted) {
                    NSString *urlString = entry[@"url"];
                    if (![urlString length]) continue;

                    long long w = [entry[@"width"] longLongValue];
                    long long h = [entry[@"height"] longLongValue];

                    [legacy addObject:@{
                        @"label": (w > 0 && h > 0)
                            ? [NSString stringWithFormat:@"%lld×%lld", w, h]
                            : SCILocalized(@"quality_unknown"),
                        @"url": [NSURL URLWithString:urlString],
                        @"area": @(w * h)
                    }];
                }

                [legacy sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                    return [b[@"area"] compare:a[@"area"]];
                }];

                NSArray *deduped = [self deduplicated:[self normalised:legacy]];
                if (deduped.count > out.count) return deduped;
            }
        }
    } @catch (__unused id e) {}

    // Last resort: some builds only expose -allVideoURLs, an UNORDERED set of raw
    // URLs with no resolution metadata. If that yields more than one link, still
    // offer a picker — labelled generically — rather than silently taking one.
    if (out.count <= 1) {
        @try {
            if ([video respondsToSelector:@selector(allVideoURLs)]) {
                id urls = [video allVideoURLs];
                NSArray *urlArray = nil;
                if ([urls isKindOfClass:[NSSet class]]) urlArray = [(NSSet *)urls allObjects];
                else if ([urls isKindOfClass:[NSArray class]]) urlArray = urls;

                if (urlArray.count > 1) {
                    NSMutableArray<NSDictionary *> *generic = [NSMutableArray array];
                    NSInteger i = 1;
                    for (id u in urlArray) {
                        NSString *urlString = [u isKindOfClass:[NSURL class]] ? [(NSURL *)u absoluteString]
                                            : ([u isKindOfClass:[NSString class]] ? u : nil);
                        if (![urlString length]) continue;
                        [generic addObject:@{
                            @"label": [NSString stringWithFormat:@"%@ %ld", SCILocalized(@"quality_pick_title"), (long)i++],
                            @"urlString": urlString,
                            @"area": @(0),
                            @"bandwidth": @(0)
                        }];
                    }
                    NSArray *deduped = [self deduplicated:generic];
                    if (deduped.count > out.count) return deduped;
                }
            }
        } @catch (__unused id e) {}
    }

    return out;
}

/// Extracts the multi-resolution ladder from a video's DASH manifest.
///
/// Instagram frequently ships a single progressive rendition in -videoVersions and
/// keeps the higher resolutions (1080p, etc.) as <Representation> entries inside a
/// DASH MPD. Each video Representation carries width/height/bandwidth attributes and
/// a <BaseURL> that points at a directly-downloadable file.
+ (NSArray<NSDictionary *> *)qualitiesFromDashForVideo:(IGVideo *)video {
    NSString *xml = nil;

    @try {
        for (NSString *sel in @[@"videoDashManifest", @"dashManifest", @"videoDashManifestXML"]) {
            if ([video respondsToSelector:NSSelectorFromString(sel)]) {
                id value = [video valueForKey:sel];
                if ([value isKindOfClass:[NSString class]] && [value length]) { xml = value; break; }
                // Some builds wrap the XML in an object.
                for (NSString *inner in @[@"xmlString", @"manifest", @"string"]) {
                    @try {
                        if ([value respondsToSelector:NSSelectorFromString(inner)]) {
                            id s = [value valueForKey:inner];
                            if ([s isKindOfClass:[NSString class]] && [s length]) { xml = s; break; }
                        }
                    } @catch (__unused id e) {}
                }
                if ([xml length]) break;
            }
        }
    } @catch (__unused id e) {}

    if (![xml length]) {
        [SCIDiagnostics recordDashResult:@"no manifest exposed by this build"];
        return @[];
    }
    if ([xml rangeOfString:@"<Representation"].location == NSNotFound) {
        [SCIDiagnostics recordDashResult:@"manifest found, but no <Representation> tags"];
        return @[];
    }

    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];

    NSRegularExpression *repRegex =
        [NSRegularExpression regularExpressionWithPattern:@"<Representation\\b[^>]*>.*?</Representation>"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil];

    NSArray<NSTextCheckingResult *> *matches =
        [repRegex matchesInString:xml options:0 range:NSMakeRange(0, xml.length)];

    for (NSTextCheckingResult *match in matches) {
        NSString *block = [xml substringWithRange:match.range];

        long long w = [self dashAttribute:@"width" inBlock:block];
        long long h = [self dashAttribute:@"height" inBlock:block];
        long long bandwidth = [self dashAttribute:@"bandwidth" inBlock:block];

        // A Representation without width/height is the audio track — skip it.
        if (w <= 0 || h <= 0) continue;

        NSString *baseURL = [self dashBaseURLInBlock:block];
        if (![baseURL length]) continue;

        [out addObject:@{
            @"label": [self labelForWidth:w height:h bandwidth:bandwidth],
            @"urlString": baseURL,
            @"area": @(w * h),
            @"bandwidth": @(bandwidth)
        }];
    }

    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSComparisonResult byArea = [b[@"area"] compare:a[@"area"]];
        if (byArea != NSOrderedSame) return byArea;
        return [b[@"bandwidth"] compare:a[@"bandwidth"]];
    }];

    [SCIDiagnostics recordDashResult:[NSString stringWithFormat:@"%ld video reps: %@",
                                      (long)out.count,
                                      [[out valueForKey:@"label"] componentsJoinedByString:@" | "]]];

    return out;
}

/// Reads an integer attribute (width="1080") out of a Representation block.
+ (long long)dashAttribute:(NSString *)name inBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@=\"(\\d+)\"", name]
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return 0;
    return [[block substringWithRange:[m rangeAtIndex:1]] longLongValue];
}

/// Reads and XML-unescapes the <BaseURL> of a Representation block.
+ (NSString *)dashBaseURLInBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"<BaseURL>(.*?)</BaseURL>"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return nil;

    NSString *url = [[block substringWithRange:[m rangeAtIndex:1]]
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    url = [url stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    url = [url stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    url = [url stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    url = [url stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];

    // Only accept absolute links — relative BaseURLs need an MPD base we don't track.
    if (![url hasPrefix:@"http"]) return nil;

    return url;
}

/// "1080×1920 · 4.2 Mbps", or just the resolution when no bitrate is reported.
+ (NSString *)labelForWidth:(long long)width height:(long long)height bandwidth:(long long)bandwidth {
    if (width <= 0 || height <= 0) return SCILocalized(@"quality_unknown");

    NSString *resolution = [NSString stringWithFormat:@"%lld×%lld", width, height];
    if (bandwidth <= 0) return resolution;

    return [NSString stringWithFormat:@"%@ · %.1f Mbps", resolution, bandwidth / 1000000.0];
}

/// Guarantees every entry carries a usable string key, whether it arrived with an
/// NSURL, a string, or an NSURL that failed to parse.
+ (NSArray<NSDictionary *> *)normalised:(NSArray<NSDictionary *> *)qualities {
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];

    for (NSDictionary *quality in qualities) {
        if (quality[@"urlString"]) {
            [out addObject:quality];
            continue;
        }

        NSString *string = [(NSURL *)quality[@"url"] absoluteString];
        if (![string length]) continue;

        NSMutableDictionary *copy = [quality mutableCopy];
        copy[@"urlString"] = string;

        [out addObject:copy];
    }

    return out;
}

/// Tolerant URL construction. Instagram CDN links occasionally contain characters
/// that +URLWithString: rejects outright; percent-encoding rescues those instead of
/// losing the rendition.
+ (NSURL *)urlFromQuality:(NSDictionary *)quality {
    NSURL *direct = quality[@"url"];
    if (direct) return direct;

    NSString *string = quality[@"urlString"];
    if (![string length]) return nil;

    NSURL *url = [NSURL URLWithString:string];
    if (url) return url;

    NSString *encoded = [string stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLQueryAllowedCharacterSet]];

    return [NSURL URLWithString:encoded];
}

/// Deduplicates on the link, not the label. Two renditions can legitimately share a
/// resolution while differing in bitrate, and both are real choices.
+ (NSArray<NSDictionary *> *)deduplicated:(NSArray<NSDictionary *> *)qualities {
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSDictionary *quality in qualities) {
        if (![quality[@"label"] length]) continue;

        // Key on whatever identifies the rendition. A rendition is never dropped
        // for failing to produce an NSURL — that is resolved later, tolerantly.
        NSString *key = quality[@"urlString"];
        if (![key length]) key = [(NSURL *)quality[@"url"] absoluteString];
        if (![key length]) key = quality[@"label"];

        if ([seen containsObject:key]) continue;

        [seen addObject:key];
        [out addObject:quality];
    }

    return out;
}

// MARK: - Entry points

+ (void)downloadVideo:(IGVideo *)video sourceLabel:(NSString *)sourceLabel anchor:(UIView *)anchor {
    if (!video) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    NSArray<NSDictionary *> *qualities = [self qualitiesForVideo:video];

    // Recorded even when the picker is off, so diagnostics can distinguish
    // "no renditions found" from "feature disabled".
    [SCIDiagnostics recordQualityCount:(NSInteger)qualities.count
                         forVideoClass:NSStringFromClass([video class])];

    if (![SCIUtils getBoolPref:@"show_quality_picker"]) qualities = nil;

    // Only worth asking when there's an actual choice.
    if (qualities.count > 1) {
        [self presentQualityPicker:qualities sourceLabel:sourceLabel anchor:anchor];
        return;
    }

    NSURL *url = [SCIUtils getVideoUrl:video];
    if (!url) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    [self downloadURL:url sourceLabel:sourceLabel isVideo:YES];
}

+ (void)presentQualityPicker:(NSArray<NSDictionary *> *)qualities
                 sourceLabel:(NSString *)sourceLabel
                      anchor:(UIView *)anchor {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"quality_pick_title")
                                             message:nil
                                      preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *quality in qualities) {
        NSURL *url = [self urlFromQuality:quality];
        if (!url) continue;

        [sheet addAction:[UIAlertAction actionWithTitle:quality[@"label"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [SCIMediaDownloader downloadURL:url sourceLabel:sourceLabel isVideo:YES];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // An unanchored action sheet is fatal on iPad.
    if (anchor) {
        sheet.popoverPresentationController.sourceView = anchor;
        sheet.popoverPresentationController.sourceRect = anchor.bounds;
    }

    [topMostController() presentViewController:sheet animated:YES completion:nil];
}

+ (void)downloadURL:(NSURL *)url sourceLabel:(NSString *)sourceLabel isVideo:(BOOL)isVideo {
    if (!url) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    NSString *extension = [[url lastPathComponent] pathExtension];

    // Queue mode: hand off and let the transfer run in the background.
    if ([SCIUtils getBoolPref:@"dl_use_queue"]) {
        SCIDownloadQueue *queue = [SCIDownloadQueue shared];

        SCIDownloadJob *existing = [queue completedJobForURL:url];
        if (existing) {
            [SCIUtils showToastForDuration:1.6
                                     title:SCILocalized(@"dl_already_downloaded")
                                  subtitle:existing.displayName];
            return;
        }

        [queue enqueueURL:url fileExtension:extension displayName:nil sourceLabel:sourceLabel];
        [SCIUtils showToastForDuration:1.2 title:SCILocalized(@"dl_added_to_queue")];

        return;
    }

    // Direct mode: the original blocking HUD flow.
    BOOL toPhotos = [SCIUtils getBoolPref:@"dw_save_to_camera"];

    DownloadAction action = toPhotos
        ? saveToPhotos
        : (isVideo ? share : quickLook);

    SCIDownloadDelegate *delegate = [[SCIDownloadDelegate alloc] initWithAction:action showProgress:isVideo];

    [delegate downloadFileWithURL:url fileExtension:extension hudLabel:nil];
}

/// Whether this IGVideo can actually produce a download.
///
/// A photo post still hands back a non-nil IGVideo — an empty shell with no
/// renditions. Treating "video != nil" as "this is a video" sent every photo down
/// the video path, where it failed with "could not extract URL" while the
/// long-press path, which checks the photo directly, worked fine.
+ (BOOL)hasPlayableVideo:(IGVideo *)video {
    if (!video) return NO;

    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];

            if ([versions respondsToSelector:@selector(count)] && [versions count] > 0) return YES;
        }
    } @catch (__unused id e) {}

    // No rendition list, but another accessor may still resolve a URL.
    return ([SCIUtils getVideoUrl:video] != nil);
}

+ (void)downloadMedia:(id)media sourceLabel:(NSString *)sourceLabel anchor:(UIView *)anchor {
    if (!media) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    // Video wins — but only a real one. A video post also carries a poster photo,
    // and a photo post carries an empty video.
    IGVideo *video = nil;
    @try { video = [media valueForKey:@"video"]; } @catch (__unused id e) {}

    if ([self hasPlayableVideo:video]) {
        [SCIDiagnostics recordDownloadKind:@"video"];
        [self downloadVideo:video sourceLabel:sourceLabel anchor:anchor];
        return;
    }

    NSURL *photoUrl = [SCIUtils getPhotoUrlForMedia:media];
    if (photoUrl) {
        [SCIDiagnostics recordDownloadKind:@"photo"];
        [self downloadURL:photoUrl sourceLabel:sourceLabel isVideo:NO];
        return;
    }

    [SCIDiagnostics recordDownloadKind:@"neither — resolution failed"];

    [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
}

@end
