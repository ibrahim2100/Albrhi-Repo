#import "SCIMediaDownloader.h"
#import "Download.h"
#import "Queue/SCIDownloadQueue.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"

@implementation SCIMediaDownloader

// MARK: - Qualities

+ (NSArray<NSDictionary *> *)qualitiesForVideo:(IGVideo *)video {
    if (!video) return @[];

    // Primary shape on current builds: IGAPIVideoVersion objects.
    NSArray<NSDictionary *> *versions = [SCIUtils availableVideoQualitiesForVideo:video];

    NSMutableArray<NSDictionary *> *out = [[self deduplicated:versions] mutableCopy];
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

/// Instagram often lists the same rendition twice under different CDN hosts;
/// offering "1080×1920" three times makes the picker look broken.
+ (NSArray<NSDictionary *> *)deduplicated:(NSArray<NSDictionary *> *)qualities {
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seenLabels = [NSMutableSet set];

    for (NSDictionary *quality in qualities) {
        NSString *label = quality[@"label"];
        if (![label length] || !quality[@"url"]) continue;
        if ([seenLabels containsObject:label]) continue;

        [seenLabels addObject:label];
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

    NSArray<NSDictionary *> *qualities = [SCIUtils getBoolPref:@"show_quality_picker"]
        ? [self qualitiesForVideo:video]
        : nil;

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
        NSURL *url = quality[@"url"];

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
