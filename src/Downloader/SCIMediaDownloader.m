#import "SCIMediaDownloader.h"
#import "Download.h"
#import "Queue/SCIDownloadQueue.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Settings/SCIDiagnosticsViewController.h"
#import <objc/runtime.h>

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

/// Normalises a manifest-ish value to an XML string — it may already be a string,
/// or an object wrapping one.
+ (NSString *)manifestStringFromValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) return [value length] ? value : nil;

    // IG 410 exposes -dashManifestData, which hands back the raw XML as NSData.
    if ([value isKindOfClass:[NSData class]]) {
        NSString *s = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
        return [s length] ? s : nil;
    }

    for (NSString *inner in @[@"xmlString", @"manifest", @"string", @"dashManifest", @"data", @"value"]) {
        @try {
            if ([value respondsToSelector:NSSelectorFromString(inner)]) {
                id s = [value valueForKey:inner];
                if ([s isKindOfClass:[NSString class]] && [s length]) return s;
            }
        } @catch (__unused id e) {}
    }
    return nil;
}

/// Finds the DASH manifest XML on a video without hard-coding the selector name.
/// Known guesses are tried first; failing that, every zero-argument,
/// object-returning selector whose name mentions "dash" or "manifest" is probed,
/// and the names are collected so diagnostics can show what this build exposes.
+ (NSString *)dashXMLForVideo:(IGVideo *)video candidates:(NSMutableArray<NSString *> *)candidates {
    if (!video) return nil;

    for (NSString *sel in @[@"dashManifestData", @"videoDashManifest", @"dashManifest", @"videoDashManifestXML", @"videoDashManifestXml", @"dashPlaybackManifest"]) {
        @try {
            if ([video respondsToSelector:NSSelectorFromString(sel)]) {
                NSString *s = [self manifestStringFromValue:[video valueForKey:sel]];
                if ([s length]) return s;
            }
        } @catch (__unused id e) {}
    }

    Class cls = object_getClass(video);
    while (cls && cls != [NSObject class]) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);

        for (unsigned int i = 0; i < count; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(sel);

            if ([name rangeOfString:@":"].location != NSNotFound) continue; // takes arguments

            NSString *lower = name.lowercaseString;
            if (![lower containsString:@"dash"] && ![lower containsString:@"manifest"]) continue;

            [candidates addObject:name];

            @try {
                NSMethodSignature *sig = [video methodSignatureForSelector:sel];
                if (!sig || sig.numberOfArguments != 2) continue;      // self, _cmd only
                const char *ret = sig.methodReturnType;
                if (ret == NULL || ret[0] != '@') continue;             // must return an object

                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                inv.selector = sel;
                inv.target = video;
                [inv invoke];

                __unsafe_unretained id result = nil;
                [inv getReturnValue:&result];

                NSString *s = [self manifestStringFromValue:result];
                if ([s length] && ([s containsString:@"<MPD"] || [s containsString:@"<mpd"] || [s containsString:@"Representation"])) {
                    free(methods);
                    return s;
                }
            } @catch (__unused id e) {}
        }

        free(methods);
        cls = class_getSuperclass(cls);
    }

    return nil;
}

/// Extracts the multi-resolution ladder from a video's DASH manifest.
///
/// Instagram frequently ships a single progressive rendition in -videoVersions and
/// keeps the higher resolutions (1080p, etc.) as <Representation> entries inside a
/// DASH MPD. Each video Representation carries width/height/bandwidth attributes and
/// a <BaseURL> that points at a directly-downloadable file.
+ (NSArray<NSDictionary *> *)qualitiesFromDashForVideo:(IGVideo *)video {
    // The DASH selector name varies between builds and isn't one of the obvious
    // guesses on IG 410, so find it reflectively and report what we saw.
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSString *xml = [self dashXMLForVideo:video candidates:candidates];

    if (![xml length]) {
        [SCIDiagnostics recordDashResult:candidates.count
            ? [NSString stringWithFormat:@"no usable manifest; candidates: %@", [candidates componentsJoinedByString:@", "]]
            : @"no dash/manifest selector on this build"];
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
    // The \\b matters: without it, width="…" matches inside bandWIDTH="…", so the
    // bitrate was being read as the width (e.g. "1421375×2560").
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@=\"(\\d+)\"", name]
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

    [SCIDiagnostics recordPickedURL:[url absoluteString]];

    NSString *extension = [[url lastPathComponent] pathExtension];

    // DASH BaseURLs and other CDN links often carry no file extension (or a query
    // string). Photos rejects an extension-less video, which surfaces as a failure —
    // fall back to a sensible default for the media kind.
    if (![extension length] || [extension length] > 4) {
        extension = isVideo ? @"mp4" : @"jpg";
    }

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

// MARK: - On-screen story download

+ (void)downloadVisibleStoryInView:(UIView *)root anchor:(UIView *)anchor {
    id media = [self currentStoryMediaInView:root];
    if (!media) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    [self downloadMedia:media sourceLabel:nil anchor:(anchor ?: root)];
}

/// Locates the media of the story currently on screen. Adjacent stories are kept
/// mounted off-screen, so the candidate covering the viewer's centre wins.
+ (id)currentStoryMediaInView:(UIView *)root {
    if (!root) return nil;

    CGPoint centre = CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds));
    return [self storyMediaSearchIn:root root:root centre:centre];
}

+ (id)storyMediaSearchIn:(UIView *)view root:(UIView *)root centre:(CGPoint)centre {
    if (!view) return nil;

    static NSArray<NSString *> *itemClasses = nil;
    static NSArray<NSString *> *legacyClasses = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        itemClasses = @[@"IGStoryModernVideoView", @"IGStoryPhotoView"];
        legacyClasses = @[@"IGStoryVideoView"];
    });

    if (!view.hidden && view.alpha > 0.05 && !CGRectIsEmpty(view.bounds)) {
        BOOL coversCentre = CGRectContainsPoint([view convertRect:view.bounds toView:root], centre);
        NSString *cls = NSStringFromClass([view class]);

        if (coversCentre) {
            for (NSString *name in itemClasses) {
                Class c = NSClassFromString(name);
                if (c && [view isKindOfClass:c]) {
                    @try { id item = [view valueForKey:@"item"]; if (item) return item; } @catch (__unused id e) {}
                }
            }
            for (NSString *name in legacyClasses) {
                Class c = NSClassFromString(name);
                if (c && [view isKindOfClass:c]) {
                    @try {
                        id caption = [view valueForKey:@"captionDelegate"];
                        id item = caption ? [caption valueForKey:@"currentStoryItem"] : nil;
                        if (item) return item;
                    } @catch (__unused id e) {}
                }
            }
            (void)cls;
        }
    }

    for (UIView *sub in view.subviews) {
        id media = [self storyMediaSearchIn:sub root:root centre:centre];
        if (media) return media;
    }

    return nil;
}

@end
