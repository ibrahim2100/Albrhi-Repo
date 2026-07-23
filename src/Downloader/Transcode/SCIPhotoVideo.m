#import "SCIPhotoVideo.h"
#import "SCITranscodeBanner.h"
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

// Low enough that a minute of video is a handful of frames, high enough that
// every player treats the result as a normal clip. The picture never changes, so
// nothing is lost by not sending thirty of them a second.
static const int32_t kFrameRate = 6;

// Instagram's own images are large; the render matches whatever it was given,
// capped so an unusually big photo cannot ask the encoder for a size it will
// refuse.
static const CGFloat kMaximumSide = 1920.0;

@implementation SCIPhotoVideo

+ (NSTimeInterval)maximumDuration { return 90.0; }

// MARK: - Fetch

+ (NSString *)downloadToTemp:(NSURL *)url extension:(NSString *)ext {
    if (!url) return nil;

    __block NSString *path = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);

    NSURLSessionDownloadTask *task =
        [[NSURLSession sharedSession] downloadTaskWithURL:url
                                        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (location && !error) {
                NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                  [[NSUUID UUID].UUIDString stringByAppendingPathExtension:ext]];
                if ([[NSFileManager defaultManager] moveItemAtURL:location
                                                            toURL:[NSURL fileURLWithPath:dest]
                                                            error:nil]) {
                    path = dest;
                }
            }
            dispatch_semaphore_signal(done);
        }];

    [task resume];

    // Bounded, so a stalled CDN cannot leave the banner up forever.
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)) != 0) {
        [task cancel];
        return nil;
    }
    return path;
}

// MARK: - The still frame

/// The photo as a pixel buffer, at even dimensions — H.264 requires them, and an
/// odd width is a silent encoder failure rather than an error.
+ (CVPixelBufferRef)pixelBufferFromImage:(UIImage *)image size:(CGSize *)outSize CF_RETURNS_RETAINED {
    CGFloat width = image.size.width * image.scale;
    CGFloat height = image.size.height * image.scale;
    if (width < 2 || height < 2) return NULL;

    CGFloat scale = MIN(1.0, kMaximumSide / MAX(width, height));
    width = floor(width * scale / 2.0) * 2.0;
    height = floor(height * scale / 2.0) * 2.0;

    NSDictionary *attributes = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };

    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, (size_t)width, (size_t)height,
                            kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)attributes, &buffer) != kCVReturnSuccess) {
        return NULL;
    }

    CVPixelBufferLockBaseAddress(buffer, 0);

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(buffer),
                                                 (size_t)width, (size_t)height, 8,
                                                 CVPixelBufferGetBytesPerRow(buffer), space,
                                                 kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);

    if (context) {
        // Filled black first: a photo with transparency would otherwise land on
        // uninitialised memory rather than a background.
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, width, height));
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
        CGContextRelease(context);
    }

    CGColorSpaceRelease(space);
    CVPixelBufferUnlockBaseAddress(buffer, 0);

    if (outSize) *outSize = CGSizeMake(width, height);
    return buffer;
}

// MARK: - Render

+ (BOOL)renderPhoto:(NSString *)photoPath
              audio:(NSString *)audioPath
           duration:(NSTimeInterval)seconds
             output:(NSString *)output
           progress:(void (^)(float))progress {

    UIImage *image = [UIImage imageWithContentsOfFile:photoPath];
    if (!image) return NO;

    CGSize size = CGSizeZero;
    CVPixelBufferRef frame = [self pixelBufferFromImage:image size:&size];
    if (!frame) return NO;

    [[NSFileManager defaultManager] removeItemAtPath:output error:nil];

    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:output]
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    if (!writer) { CVPixelBufferRelease(frame); return NO; }

    AVAssetWriterInput *video =
        [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                           outputSettings:@{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(size.width),
            AVVideoHeightKey: @(size.height)
        }];
    video.expectsMediaDataInRealTime = NO;

    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:video
                                                                        sourcePixelBufferAttributes:nil];

    if ([writer canAddInput:video]) [writer addInput:video];

    // Audio is optional in the sense that a failure to read it should still
    // produce the clip — silent, but saved — rather than nothing at all.
    AVAssetReader *reader = nil;
    AVAssetReaderTrackOutput *readerOutput = nil;
    AVAssetWriterInput *audio = nil;

    if (audioPath) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:audioPath]];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;

        if (track) {
            reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
            // Read only the span being rendered; a three-minute song behind a ten
            // second clip would otherwise be decoded in full for nothing.
            reader.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(seconds, 600));

            readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                                     outputSettings:@{ AVFormatIDKey: @(kAudioFormatLinearPCM) }];
            if ([reader canAddOutput:readerOutput]) [reader addOutput:readerOutput];

            audio = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                      outputSettings:@{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVSampleRateKey: @44100,
                AVNumberOfChannelsKey: @2,
                AVEncoderBitRateKey: @128000
            }];
            audio.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:audio]) [writer addInput:audio];
        }
    }

    if (![writer startWriting]) { CVPixelBufferRelease(frame); return NO; }
    [writer startSessionAtSourceTime:kCMTimeZero];

    // Video first, and it is tiny: identical frames cost the encoder nothing
    // after the first, so this finishes long before the audio does.
    NSInteger total = MAX(2, (NSInteger)(seconds * kFrameRate));

    for (NSInteger i = 0; i < total; i++) {
        while (!video.isReadyForMoreMediaData && writer.status == AVAssetWriterStatusWriting) {
            [NSThread sleepForTimeInterval:0.005];
        }
        if (writer.status != AVAssetWriterStatusWriting) break;

        [adaptor appendPixelBuffer:frame withPresentationTime:CMTimeMake(i, kFrameRate)];

        if (progress && i % kFrameRate == 0) progress((float)i / (float)total * 0.5f);
    }
    [video markAsFinished];
    CVPixelBufferRelease(frame);

    if (reader && audio && [reader startReading]) {
        CMSampleBufferRef sample;
        while ((sample = [readerOutput copyNextSampleBuffer])) {
            while (!audio.isReadyForMoreMediaData && writer.status == AVAssetWriterStatusWriting) {
                [NSThread sleepForTimeInterval:0.005];
            }
            if (writer.status == AVAssetWriterStatusWriting) [audio appendSampleBuffer:sample];
            CFRelease(sample);
            if (writer.status != AVAssetWriterStatusWriting) break;
        }
        [audio markAsFinished];
    } else if (audio) {
        [audio markAsFinished];
    }

    if (progress) progress(0.95f);

    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];

    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC)) != 0) {
        return NO;
    }

    return writer.status == AVAssetWriterStatusCompleted;
}

// MARK: - Offer

+ (void)renderAndSave:(NSURL *)photo audio:(NSURL *)audio seconds:(NSTimeInterval)seconds {
    SCITranscodeBanner *banner = [SCITranscodeBanner shared];
    [banner showWithTitle:[NSString stringWithFormat:SCILocalized(@"photovid_working"), (long)seconds]];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *photoPath = [self downloadToTemp:photo extension:@"jpg"];
        NSString *audioPath = [self downloadToTemp:audio extension:@"m4a"];

        if (!photoPath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [banner finishWithSuccess:NO message:SCILocalized(@"photovid_failed")];
            });
            return;
        }

        NSString *output = [NSTemporaryDirectory() stringByAppendingPathComponent:
                            [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];

        BOOL ok = [self renderPhoto:photoPath audio:audioPath duration:seconds output:output
                           progress:^(float fraction) {
            [banner setDetail:SCILocalized(@"photovid_rendering") fraction:fraction];
        }];

        for (NSString *path in @[photoPath, audioPath ?: @""]) {
            if (path.length) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }

        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [banner finishWithSuccess:NO message:SCILocalized(@"photovid_failed")];
            });
            return;
        }

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:output]];
        } completionHandler:^(BOOL success, NSError *saveError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSFileManager defaultManager] removeItemAtPath:output error:nil];
                [banner finishWithSuccess:success
                                  message:success ? SCILocalized(@"photovid_saved")
                                                  : SCILocalized(@"photovid_failed")];
            });
        }];
    });
}

+ (void)offerForPhoto:(NSURL *)photo audio:(NSURL *)audio {
    if (!photo || !audio) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"photovid_title")
                                            message:SCILocalized(@"photovid_body")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *seconds in @[@5, @10, @15, @30, @60, @(SCIPhotoVideo.maximumDuration)]) {
        NSString *label = [NSString stringWithFormat:SCILocalized(@"photovid_seconds"),
                           (long)seconds.integerValue];

        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self renderAndSave:photo audio:audio seconds:seconds.doubleValue];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIViewController *host = topMostController();

    // An action sheet without an anchor is fatal on iPad.
    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMaxY(host.view.bounds) - 40, 1, 1);

    [host presentViewController:sheet animated:YES completion:nil];
}

@end
