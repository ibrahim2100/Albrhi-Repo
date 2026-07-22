#import "SCIMediaDownloader.h"
#import "Download.h"
#import "Queue/SCIDownloadQueue.h"
#import "Transcode/SCIAV1Transcoder.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Settings/SCIDiagnosticsViewController.h"
#import <objc/runtime.h>
#import <Photos/Photos.h>

@implementation SCIMediaDownloader

// MARK: - Qualities

// MARK: - Entry points

+ (void)downloadVideo:(IGVideo *)video sourceLabel:(NSString *)sourceLabel anchor:(UIView *)anchor {
    if (!video) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    // Best saveable rendition: the DASH ladder often carries a higher H.264/HEVC
    // than -videoVersions exposes. -getBestVideoUrl: falls back to the proven
    // -videoVersions path whenever DASH offers nothing iOS can save.
    NSURL *url = [SCIUtils getBestVideoUrl:video];

    if (!url) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    [SCIDiagnostics recordQualityCount:1 forVideoClass:NSStringFromClass([video class])];

    [self downloadURL:url sourceLabel:sourceLabel isVideo:YES];
}

/// Reels can be saved as video or as the original audio track.
+ (void)presentVideoOrAudioChoiceForVideo:(IGVideo *)video
                                 audioURL:(NSURL *)audioURL
                              sourceLabel:(NSString *)sourceLabel
                                   anchor:(UIView *)anchor {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dw_choice_video")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [SCIMediaDownloader downloadVideo:video sourceLabel:sourceLabel anchor:anchor];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dw_choice_audio")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [SCIMediaDownloader downloadURL:audioURL sourceLabel:sourceLabel isVideo:NO];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

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

        // Probed here rather than in -downloadVideo:, which never receives the
        // media object: the first attempt passed nil for it and so only ever
        // questioned IGVideo. Read-only — nothing downstream uses the result yet.
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        for (id host in @[video, media]) {
            for (NSString *name in [SCIUtils selectorsMatching:@"dash" onObject:host]) {
                if (![candidates containsObject:name]) [candidates addObject:name];
            }
            for (NSString *name in [SCIUtils selectorsMatching:@"manifest" onObject:host]) {
                if (![candidates containsObject:name]) [candidates addObject:name];
            }
        }

        [SCIDiagnostics recordDashManifest:[SCIUtils dashManifestXMLForVideo:video media:media]
                                candidates:candidates];

        // Reel audio used to be offered by the long-press handler, which no longer
        // exists. The choice lives here now so the setting keeps working.
        NSURL *audioUrl = [SCIUtils getBoolPref:@"dw_reel_audio"]
            ? [SCIUtils getAudioUrlForMedia:media]
            : nil;

        if (audioUrl) {
            [self presentVideoOrAudioChoiceForVideo:video
                                           audioURL:audioUrl
                                        sourceLabel:sourceLabel
                                             anchor:anchor];
            return;
        }

        // Opt-in: when the only higher quality is AV1 (which iOS cannot save),
        // transcode it to H.264 on device. Falls back to the progressive
        // download on any failure, so this can never leave the user empty-handed.
        if ([self tryTranscodeForVideo:video media:media sourceLabel:sourceLabel]) {
            return;
        }

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

// MARK: - AV1 transcode

/// Attempts the on-device AV1→H.264 transcode when it would raise the quality and
/// the user has opted in. Returns YES if it took over the download (running in the
/// background), NO to let the normal progressive path proceed.
+ (BOOL)tryTranscodeForVideo:(IGVideo *)video media:(id)media sourceLabel:(NSString *)sourceLabel {
    if (![SCIUtils getBoolPref:@"dw_transcode_av1"]) return NO;

    NSDictionary *plan = [SCIUtils transcodePlanForVideo:video media:media];
    if (!plan) return NO;

    NSString *label = [NSString stringWithFormat:SCILocalized(@"transcode_progress"),
                       [plan[@"height"] intValue]];
    JGProgressHUD *hud = [SCIUtils showProgressHUDWithText:label];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *out = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];

        BOOL ok = [SCIAV1Transcoder transcodeVideoURL:plan[@"videoURL"]
                                             audioURL:plan[@"audioURL"]
                                                  fps:[plan[@"fps"] doubleValue]
                                         toOutputPath:out];

        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissAnimated:YES];

            if (ok) {
                [self saveTranscodedFile:out];
            } else {
                // The transcode named its failing stage in diagnostics; the user
                // still gets the progressive rendition.
                [SCIUtils showToastForDuration:1.4 title:SCILocalized(@"transcode_fell_back")];
                [self downloadVideo:video sourceLabel:sourceLabel anchor:nil];
            }
        });
    });

    return YES;
}

+ (void)saveTranscodedFile:(NSString *)path {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:path]];
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            if (success) {
                [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"transcode_saved")];
            } else {
                [SCIUtils showErrorHUDWithDescription:(error.localizedDescription ?: SCILocalized(@"err_save_failed"))];
            }
        });
    }];
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
