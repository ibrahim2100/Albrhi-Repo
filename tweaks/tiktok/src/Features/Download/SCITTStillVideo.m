#import "SCITTStillVideo.h"
#import "../../SCILog.h"
#import <AVFoundation/AVFoundation.h>

/// 15 frames a second for a picture that never moves.
///
/// Nothing in the frame changes, so every frame after the first is the same pixel buffer -- but a
/// video track still needs frames spread across its duration or players show a black screen after
/// the first instant. Fifteen is enough for that and keeps a 60-second export at 900 appends of an
/// already-rendered buffer, which costs nothing measurable.
static const int32_t kSCIStillFPS = 15;

@implementation SCITTStillVideo

/// The image drawn into a pixel buffer once, at even dimensions.
///
/// H.264 requires even width and height, and a photo whose size is odd by one pixel fails the
/// encoder rather than being rounded for you.
static CVPixelBufferRef SCITTPixelBufferForImage(UIImage *image, CGSize size) {
    NSDictionary *attributes = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
    };

    CVPixelBufferRef buffer = NULL;
    CVReturn created = CVPixelBufferCreate(kCFAllocatorDefault,
                                           (size_t)size.width, (size_t)size.height,
                                           kCVPixelFormatType_32ARGB,
                                           (__bridge CFDictionaryRef)attributes,
                                           &buffer);
    if (created != kCVReturnSuccess || !buffer) return NULL;

    CVPixelBufferLockBaseAddress(buffer, 0);

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(buffer),
                                                 (size_t)size.width, (size_t)size.height,
                                                 8, CVPixelBufferGetBytesPerRow(buffer),
                                                 space,
                                                 // Cast written out, because the parameter is a
                                                 // `CGBitmapInfo` and the constant is a
                                                 // `CGImageAlphaInfo` -- two enums that share a bit
                                                 // field by design. **CI's clang rejects the implicit
                                                 // conversion under `-Wimplicit-enum-enum-cast` and
                                                 // the local one does not**, which is the first time
                                                 // this project has hit a warning that exists on one
                                                 // toolchain and not the other: a clean local build
                                                 // is not proof of a clean CI build.
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    if (context) {
        // Filled black first: a picture with transparency or one that does not fill an even-sized
        // canvas would otherwise carry whatever was in the buffer's memory.
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
        CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), image.CGImage);
        CGContextRelease(context);
    }

    CGColorSpaceRelease(space);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return buffer;
}

/// Writes the picture as a silent video, synchronously, and returns its file URL.
static NSURL *SCITTWriteSilentVideo(UIImage *image, NSTimeInterval seconds, NSString **failure) {
    if (!image.CGImage) {
        if (failure) *failure = @"the picture could not be read";
        return nil;
    }

    CGSize size = CGSizeMake(floor(image.size.width * image.scale / 2) * 2,
                             floor(image.size.height * image.scale / 2) * 2);
    if (size.width < 2 || size.height < 2) {
        if (failure) *failure = @"the picture has no usable size";
        return nil;
    }

    NSURL *output = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"albrhi-still-%@.mp4", [[NSUUID UUID] UUIDString]]]];

    NSError *error = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:output
                                                     fileType:AVFileTypeMPEG4
                                                        error:&error];
    if (!writer) {
        if (failure) *failure = error.localizedDescription ?: @"no writer";
        return nil;
    }

    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                  outputSettings:@{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(size.width),
        AVVideoHeightKey: @(size.height),
    }];
    input.expectsMediaDataInRealTime = NO;

    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                                                       sourcePixelBufferAttributes:nil];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    CVPixelBufferRef buffer = SCITTPixelBufferForImage(image, size);
    if (!buffer) {
        [writer cancelWriting];
        if (failure) *failure = @"the picture could not be drawn into a frame";
        return nil;
    }

    int32_t frames = (int32_t)ceil(seconds * kSCIStillFPS);
    for (int32_t frame = 0; frame < frames; frame++) {
        // Waiting rather than dropping: `-appendPixelBuffer:` refuses while the input is not ready
        // and a dropped frame here is a gap in the middle of the clip.
        int spins = 0;
        while (!input.isReadyForMoreMediaData && spins++ < 2000) {
            [NSThread sleepForTimeInterval:0.005];
        }
        if (!input.isReadyForMoreMediaData) break;

        [adaptor appendPixelBuffer:buffer
              withPresentationTime:CMTimeMake(frame, kSCIStillFPS)];
    }

    CVPixelBufferRelease(buffer);
    [input markAsFinished];
    [writer endSessionAtSourceTime:CMTimeMakeWithSeconds(seconds, kSCIStillFPS)];

    dispatch_semaphore_t wait = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{
        dispatch_semaphore_signal(wait);
    }];
    dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 60ull * NSEC_PER_SEC));

    if (writer.status != AVAssetWriterStatusCompleted) {
        if (failure) {
            *failure = writer.error.localizedDescription
                ?: [NSString stringWithFormat:@"writer status %ld", (long)writer.status];
        }
        return nil;
    }

    return output;
}

+ (void)renderImage:(UIImage *)image
           audioURL:(NSURL *)audioURL
            seconds:(NSTimeInterval)seconds
         completion:(void (^)(NSURL *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *failure = nil;
        NSURL *silent = SCITTWriteSilentVideo(image, seconds, &failure);
        if (!silent) {
            completion(nil, failure ?: @"the still video could not be written");
            return;
        }

        AVURLAsset *video = [AVURLAsset URLAssetWithURL:silent options:nil];
        AVAssetTrack *videoTrack = [video tracksWithMediaType:AVMediaTypeVideo].firstObject;
        if (!videoTrack) {
            completion(nil, @"the still video has no video track");
            return;
        }

        AVMutableComposition *composition = [AVMutableComposition composition];
        AVMutableCompositionTrack *videoSlot =
            [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                     preferredTrackID:kCMPersistentTrackID_Invalid];

        CMTime length = CMTimeMakeWithSeconds(seconds, 600);
        NSError *error = nil;
        if (![videoSlot insertTimeRange:CMTimeRangeMake(kCMTimeZero, video.duration)
                               ofTrack:videoTrack
                                atTime:kCMTimeZero
                                 error:&error]) {
            completion(nil, error.localizedDescription ?: @"the video track could not be laid down");
            return;
        }

        // **Audio is optional here, deliberately.** A post whose sound could not be resolved or
        // downloaded still produces a saveable clip of the picture; refusing the whole export
        // because the music is missing would be the "correct principle in the wrong place" mistake
        // this project has already made once, when a button was hidden because a lookup failed.
        AVAssetTrack *audioTrack = nil;
        if (audioURL) {
            AVURLAsset *audio = [AVURLAsset URLAssetWithURL:audioURL options:nil];
            audioTrack = [audio tracksWithMediaType:AVMediaTypeAudio].firstObject;

            if (audioTrack) {
                AVMutableCompositionTrack *audioSlot =
                    [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                             preferredTrackID:kCMPersistentTrackID_Invalid];

                // Trimmed to whichever is shorter: asking for ten seconds of a seven-second sound
                // is not an error, it is seven seconds of sound.
                CMTime take = CMTimeMinimum(length, audioTrack.timeRange.duration);
                [audioSlot insertTimeRange:CMTimeRangeMake(kCMTimeZero, take)
                                   ofTrack:audioTrack
                                    atTime:kCMTimeZero
                                     error:NULL];
            }
        }

        NSURL *output = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:
                [NSString stringWithFormat:@"albrhi-photo-%@.mp4", [[NSUUID UUID] UUIDString]]]];

        AVAssetExportSession *export =
            [[AVAssetExportSession alloc] initWithAsset:composition
                                             presetName:AVAssetExportPresetHighestQuality];
        export.outputURL = output;
        export.outputFileType = AVFileTypeMPEG4;

        dispatch_semaphore_t wait = dispatch_semaphore_create(0);
        [export exportAsynchronouslyWithCompletionHandler:^{
            dispatch_semaphore_signal(wait);
        }];
        dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, 120ull * NSEC_PER_SEC));

        [[NSFileManager defaultManager] removeItemAtURL:silent error:NULL];

        if (export.status != AVAssetExportSessionStatusCompleted) {
            completion(nil, export.error.localizedDescription
                ?: [NSString stringWithFormat:@"export status %ld", (long)export.status]);
            return;
        }

        SCILogV(@"still video written: %@ (%@ audio)", output, audioTrack ? @"with" : @"no");
        completion(output, nil);
    });
}

@end
