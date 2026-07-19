#import "Download.h"

@implementation SCIDownloadDelegate

- (instancetype)initWithAction:(DownloadAction)action showProgress:(BOOL)showProgress {
    self = [super init];
    
    if (self) {
        // Read-only properties
        _action = action;
        _showProgress = showProgress;

        // Properties
        self.downloadManager = [[SCIDownloadManager alloc] initWithDelegate:self];
        self.hud = [[JGProgressHUD alloc] init];
    }

    return self;
}
- (void)downloadFileWithURL:(NSURL *)url fileExtension:(NSString *)fileExtension hudLabel:(NSString *)hudLabel {
    // Show progress gui
    self.hud = [[JGProgressHUD alloc] init];
    self.hud.textLabel.text = hudLabel != nil ? hudLabel : @"Downloading";

    if (self.showProgress) {
        JGProgressHUDRingIndicatorView *indicatorView = [[JGProgressHUDRingIndicatorView alloc] init ];
        indicatorView.roundProgressLine = YES;
        indicatorView.ringWidth = 3.5;

        self.hud.indicatorView = indicatorView;
        self.hud.detailTextLabel.text = [NSString stringWithFormat:@"00%% Complete"];

        // Allow dismissing longer downloads (requiring progress updates)
        __weak typeof(self) weakSelf = self;
        self.hud.tapOutsideBlock = ^(JGProgressHUD * _Nonnull HUD) {
            [weakSelf.downloadManager cancelDownload];
        };
    }

    [self.hud showInView:topMostController().view];

    NSLog(@"[SCInsta] Download: Will start download for url \"%@\" with file extension: \".%@\"", url, fileExtension);

    // Start download using manager
    [self.downloadManager downloadFileWithURL:url fileExtension:fileExtension];
}

// Delegate methods
- (void)downloadDidStart {
    NSLog(@"[SCInsta] Download: Download started");
}
- (void)downloadDidCancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud dismiss];
    });

    NSLog(@"[SCInsta] Download: Download cancelled");
}
- (void)downloadDidProgress:(float)progress {
    NSLog(@"[SCInsta] Download: Download progress: %f", progress);
    
    if (self.showProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.hud setProgress:progress animated:false];
            self.hud.detailTextLabel.text = [NSString stringWithFormat:@"%02d%% Complete", (int)(progress * 100)];
        });
    }
}
- (void)downloadDidFinishWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Check if it actually errored (not cancelled)
        if (error && error.code != NSURLErrorCancelled) {
            NSLog(@"[SCInsta] Download: Download failed with error: \"%@\"", error);
            [SCIUtils showErrorHUDWithDescription:@"Error, try again later"];
        }
    });
}
- (void)downloadDidFinishWithFileURL:(NSURL *)fileURL {
    // If silent-video is enabled and this is a video, strip the audio track first.
    NSString *ext = [[fileURL pathExtension] lowercaseString];
    BOOL isVideo = [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"m4v"];
    BOOL silent = [[NSUserDefaults standardUserDefaults] boolForKey:@"dw_silent_video"];

    if (isVideo && silent) {
        [self stripAudioFromVideo:fileURL completion:^(NSURL *outURL) {
            [self proceedWithFinalURL:(outURL ?: fileURL)];
        }];
        return;
    }

    [self proceedWithFinalURL:fileURL];
}

- (void)proceedWithFinalURL:(NSURL *)fileURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud dismiss];

        NSLog(@"[Albrhi] Download finished: \"%@\" action %d", [fileURL absoluteString], (int)self.action);

        switch (self.action) {
            case share:
                [SCIUtils showShareVC:fileURL];
                break;
            
            case quickLook:
                [SCIUtils showQuickLookVC:@[fileURL]];
                break;

            case saveToPhotos:
                [self saveFileToPhotos:fileURL];
                break;
        }
    });
}

// Export a copy of the video with no audio track.
- (void)stripAudioFromVideo:(NSURL *)inputURL completion:(void (^)(NSURL *))completion {
    AVAsset *asset = [AVAsset assetWithURL:inputURL];
    AVMutableComposition *composition = [AVMutableComposition composition];

    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) { completion(nil); return; }

    AVMutableCompositionTrack *compVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    NSError *err = nil;
    [compVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:videoTrack
                             atTime:kCMTimeZero
                              error:&err];
    compVideoTrack.preferredTransform = videoTrack.preferredTransform; // keep orientation

    if (err) { completion(nil); return; }

    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"%@_silent.mp4", NSUUID.UUID.UUIDString]];
    NSURL *outURL = [NSURL fileURLWithPath:outPath];

    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:composition
                                                                   presetName:AVAssetExportPresetHighestQuality];
    export.outputURL = outURL;
    export.outputFileType = AVFileTypeMPEG4;
    [export exportAsynchronouslyWithCompletionHandler:^{
        if (export.status == AVAssetExportSessionStatusCompleted) {
            completion(outURL);
        } else {
            NSLog(@"[Albrhi] Silent export failed: %@", export.error);
            completion(nil);
        }
    }];
}

- (void)saveFileToPhotos:(NSURL *)fileURL {
    [SCIDownloadDelegate saveLocalFileToPhotos:fileURL];
}

// Save the downloaded media directly to the user's photo library (into an "Albrhi" album).
+ (void)saveLocalFileToPhotos:(NSURL *)fileURL {
    NSString *ext = [[fileURL pathExtension] lowercaseString];
    BOOL isVideo = [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"m4v"];

    void (^onDone)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                JGProgressHUD *doneHud = [[JGProgressHUD alloc] init];
                doneHud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                doneHud.textLabel.text = [SCILocalize stringForKey:@"download_saved"];
                [doneHud showInView:topMostController().view];
                [doneHud dismissAfterDelay:1.4];
            } else {
                NSLog(@"[Albrhi] Save to Photos failed: %@", error);
                [SCIUtils showErrorHUDWithDescription:[SCILocalize stringForKey:@"download_failed"]];
            }
        });
    };

    BOOL useAlbum = [[NSUserDefaults standardUserDefaults] boolForKey:@"custom_album"];
    [self saveAsset:fileURL isVideo:isVideo toAlbum:(useAlbum ? @"Albrhi" : nil) completion:onDone];
}

// Save an asset and add it to a named album (creating the album if needed).
+ (void)saveAsset:(NSURL *)fileURL isVideo:(BOOL)isVideo toAlbum:(NSString *)albumName completion:(void (^)(BOOL, NSError *))completion {
    // Find or create the album collection.
    PHFetchOptions *opts = [[PHFetchOptions alloc] init];
    opts.predicate = [NSPredicate predicateWithFormat:@"title = %@", albumName];
    PHAssetCollection *album = [[PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                        subtype:PHAssetCollectionSubtypeAny
                                                                        options:opts] firstObject];

    void (^saveInto)(PHAssetCollection *) = ^(PHAssetCollection *targetAlbum) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *assetReq = isVideo
                ? [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL]
                : [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];

            if (targetAlbum) {
                PHAssetCollectionChangeRequest *albumReq = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:targetAlbum];
                [albumReq addAssets:@[assetReq.placeholderForCreatedAsset]];
            }
        } completionHandler:completion];
    };

    if (album) {
        saveInto(album);
    } else {
        __block PHObjectPlaceholder *placeholder = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *createReq = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
            placeholder = createReq.placeholderForCreatedAssetCollection;
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success || !placeholder) {
                // Fall back to saving without an album.
                saveInto(nil);
                return;
            }
            PHAssetCollection *created = [[PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[placeholder.localIdentifier] options:nil] firstObject];
            saveInto(created ?: nil);
        }];
    }
}

@end