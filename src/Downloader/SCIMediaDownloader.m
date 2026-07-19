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

    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];

            if ([versions respondsToSelector:@selector(count)]) {
                [SCIDiagnostics recordRawVersionCount:(NSInteger)[versions count]];
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

    out = [[self deduplicated:out] mutableCopy];
    if (out.count > 1) return out;

    // Fall back to the generic helper if the direct read found nothing usable.
    NSArray<NSDictionary *> *helperVersions = [self deduplicated:[SCIUtils availableVideoQualitiesForVideo:video]];
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

                NSArray *deduped = [self deduplicated:legacy];
                if (deduped.count > out.count) return deduped;
            }
        }
    } @catch (__unused id e) {}

    return out;
}

/// "1080×1920 · 4.2 Mbps", or just the resolution when no bitrate is reported.
+ (NSString *)labelForWidth:(long long)width height:(long long)height bandwidth:(long long)bandwidth {
    if (width <= 0 || height <= 0) return SCILocalized(@"quality_unknown");

    NSString *resolution = [NSString stringWithFormat:@"%lld×%lld", width, height];
    if (bandwidth <= 0) return resolution;

    return [NSString stringWithFormat:@"%@ · %.1f Mbps", resolution, bandwidth / 1000000.0];
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

        NSString *key = quality[@"urlString"];
        if (![key length]) key = [(NSURL *)quality[@"url"] absoluteString];
        if (![key length]) continue;

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

+ (void)downloadMedia:(id)media sourceLabel:(NSString *)sourceLabel anchor:(UIView *)anchor {
    if (!media) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    // Video wins — a video post also carries a poster photo.
    IGVideo *video = nil;
    @try { video = [media valueForKey:@"video"]; } @catch (__unused id e) {}

    if (video) {
        [self downloadVideo:video sourceLabel:sourceLabel anchor:anchor];
        return;
    }

    NSURL *photoUrl = [SCIUtils getPhotoUrlForMedia:media];
    if (photoUrl) {
        [self downloadURL:photoUrl sourceLabel:sourceLabel isVideo:NO];
        return;
    }

    [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
}

@end
