#import "SCIAV1Transcoder.h"
#import "SCIMP4Demuxer.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CoreVideo.h>

#import <errno.h>
#import "dav1d/dav1d.h"

// Every stage records here so a device failure names where it happened.
static void stage(NSString *name, BOOL ok, NSString *detail) {
    [SCIDiagnostics recordTranscodeStage:name ok:ok detail:detail];
}

// dav1d_data_wrap takes a C function pointer, not a block. The bitstream NSData
// outlives decoding and is released by the caller, so nothing needs freeing here.
static void sciNoFreeCallback(const uint8_t *buf, void *cookie) {}

@interface SCIAV1Transcoder ()
// Declared up front so call order within the file cannot matter, and so ARC has
// the pixel buffer's CF ownership explicitly (its name is not in the create/copy
// family the compiler would otherwise infer a +1 return from).
+ (NSString *)downloadToTempFile:(NSURL *)url extension:(NSString *)ext;
+ (CVPixelBufferRef)pixelBufferFromPicture:(Dav1dPicture *)pic CF_RETURNS_RETAINED;
+ (NSArray *)encodeH264FromBitstream:(NSData *)bitstream fps:(double)fps
                            outWidth:(int *)outW outHeight:(int *)outH
                            progress:(void (^)(NSString *))progress;
+ (BOOL)muxVideoSamples:(NSArray *)samples audioPath:(NSString *)audioPath outputPath:(NSString *)outputPath;
+ (void)cleanup:(NSArray<NSString *> *)paths;
@end

@implementation SCIAV1Transcoder

// MARK: - Download

// A blocking download to a temp file. The transcoder already runs off the main
// thread, so a semaphore here keeps the pipeline linear and readable.
+ (NSString *)downloadToTempFile:(NSURL *)url extension:(NSString *)ext {
    if (!url) return nil;

    __block NSString *path = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);

    NSURLSessionDownloadTask *task =
        [[NSURLSession sharedSession] downloadTaskWithURL:url
                                        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (location && !error) {
                NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                  [[NSUUID UUID].UUIDString stringByAppendingPathExtension:ext]];
                [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
                if ([[NSFileManager defaultManager] moveItemAtURL:location
                                                            toURL:[NSURL fileURLWithPath:dest]
                                                            error:nil]) {
                    path = dest;
                }
            }
            dispatch_semaphore_signal(done);
        }];

    [task resume];

    // Bounded: a stalled CDN connection must not hang the whole transcode forever.
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 90 * NSEC_PER_SEC)) != 0) {
        [task cancel];
        return nil;
    }
    return path;
}

// MARK: - Pixel conversion

// A dav1d I420 8-bit picture as an NV12 pixel buffer VideoToolbox can encode.
// Strides differ between dav1d's planes and the pixel buffer's rows, so every
// plane is copied line by line rather than in one block.
+ (CVPixelBufferRef)pixelBufferFromPicture:(Dav1dPicture *)pic CF_RETURNS_RETAINED {
    if (pic->p.layout != DAV1D_PIXEL_LAYOUT_I420 || pic->p.bpc != 8) return NULL;

    int w = pic->p.w, h = pic->p.h;

    NSDictionary *attrs = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    };

    CVPixelBufferRef pb = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h,
                            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                            (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess) {
        return NULL;
    }

    CVPixelBufferLockBaseAddress(pb, 0);

    // Luma: straight copy, row by row.
    uint8_t *dstY = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
    size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
    const uint8_t *srcY = pic->data[0];
    ptrdiff_t srcYStride = pic->stride[0];
    for (int y = 0; y < h; y++) {
        memcpy(dstY + y * dstYStride, srcY + y * srcYStride, w);
    }

    // Chroma: dav1d keeps U and V in separate planes; NV12 interleaves them.
    uint8_t *dstUV = CVPixelBufferGetBaseAddressOfPlane(pb, 1);
    size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1);
    const uint8_t *srcU = pic->data[1];
    const uint8_t *srcV = pic->data[2];
    ptrdiff_t srcCStride = pic->stride[1];
    int cw = (w + 1) / 2, ch = (h + 1) / 2;
    for (int y = 0; y < ch; y++) {
        uint8_t *row = dstUV + y * dstUVStride;
        const uint8_t *ru = srcU + y * srcCStride;
        const uint8_t *rv = srcV + y * srcCStride;
        for (int x = 0; x < cw; x++) {
            row[2 * x]     = ru[x];
            row[2 * x + 1] = rv[x];
        }
    }

    CVPixelBufferUnlockBaseAddress(pb, 0);
    return pb;
}

// MARK: - Encode

// Collects compressed H.264 samples in encode order for the muxer.
static void encodeOutput(void *outputCallbackRefCon,
                         void *sourceFrameRefCon,
                         OSStatus status,
                         VTEncodeInfoFlags infoFlags,
                         CMSampleBufferRef sampleBuffer) {
    if (status != noErr || !sampleBuffer) return;
    if (!CMSampleBufferDataIsReady(sampleBuffer)) return;

    NSMutableArray *out = (__bridge NSMutableArray *)outputCallbackRefCon;
    @synchronized (out) {
        [out addObject:(__bridge id)sampleBuffer];
    }
}

// MARK: - Decode + encode

// Decodes the whole AV1 bitstream, encoding each frame to H.264 as it emerges so
// only the small compressed samples are held, never every raw frame at once.
+ (NSArray *)encodeH264FromBitstream:(NSData *)bitstream
                                 fps:(double)fps
                          outWidth:(int *)outW
                         outHeight:(int *)outH
                            progress:(void (^)(NSString *))progress {
    Dav1dSettings settings;
    dav1d_default_settings(&settings);

    Dav1dContext *ctx = NULL;
    if (dav1d_open(&ctx, &settings) != 0) {
        stage(@"decode", NO, @"dav1d_open failed");
        return nil;
    }

    NSMutableArray *samples = [NSMutableArray array];
    __block VTCompressionSessionRef session = NULL;
    __block int frameIndex = 0;
    __block int width = 0, height = 0;
    __block BOOL failed = NO;

    // Wrapped, not copied: the NSData outlives the loop, so a no-op free callback
    // is correct and avoids duplicating a multi-megabyte buffer.
    Dav1dData data;
    memset(&data, 0, sizeof(data));
    dav1d_data_wrap(&data, bitstream.bytes, bitstream.length, sciNoFreeCallback, NULL);

    void (^handle)(Dav1dPicture *) = ^(Dav1dPicture *pic) {
        if (session == NULL) {
            width = pic->p.w;
            height = pic->p.h;

            OSStatus s = VTCompressionSessionCreate(kCFAllocatorDefault, width, height,
                                                    kCMVideoCodecType_H264, NULL, NULL, NULL,
                                                    encodeOutput, (__bridge void *)samples, &session);
            if (s != noErr) { failed = YES; return; }

            VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel,
                                 kVTProfileLevel_H264_High_AutoLevel);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);

            int32_t keyInterval = (int32_t)MAX(1.0, fps * 2.0);
            CFNumberRef kiRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &keyInterval);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, kiRef);
            CFRelease(kiRef);

            // Enough to preserve the source without inflating a low-bitrate clip:
            // roughly 0.07 bits per pixel per second.
            int32_t bitrate = (int32_t)(width * height * fps * 0.07);
            CFNumberRef brRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &bitrate);
            VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, brRef);
            CFRelease(brRef);
        }

        CVPixelBufferRef pb = [self pixelBufferFromPicture:pic];
        if (!pb) { failed = YES; return; }

        CMTime pts = CMTimeMakeWithSeconds(frameIndex / fps, 600);
        CMTime dur = CMTimeMakeWithSeconds(1.0 / fps, 600);
        VTCompressionSessionEncodeFrame(session, pb, pts, dur, NULL, NULL, NULL);
        frameIndex++;

        // Live count so a slow transcode is visibly distinct from a stuck one.
        if (progress && frameIndex % 15 == 0) {
            progress([NSString stringWithFormat:@"%d", frameIndex]);
        }

        CVPixelBufferRelease(pb);
    };

    // Send, draining decoded frames after each push; EAGAIN just means "more data
    // needed" or "call get_picture again", not an error.
    size_t lastSize = data.sz + 1;
    int stalls = 0;
    while (data.sz > 0 && !failed) {
        int r = dav1d_send_data(ctx, &data);
        if (r < 0 && r != DAV1D_ERR(EAGAIN)) { failed = YES; break; }

        BOOL gotPicture = NO;
        Dav1dPicture pic;
        memset(&pic, 0, sizeof(pic));
        while (dav1d_get_picture(ctx, &pic) == 0) {
            handle(&pic);
            dav1d_picture_unref(&pic);
            gotPicture = YES;
            if (failed) break;
        }

        // Guard against a malformed stream that neither advances nor errors:
        // if a pass consumes no bytes and yields no frame, give up rather than spin.
        if (data.sz == lastSize && !gotPicture) {
            if (++stalls > 32) { failed = YES; break; }
        } else {
            stalls = 0;
        }
        lastSize = data.sz;
    }

    // Drain whatever is still buffered.
    if (!failed) {
        for (;;) {
            Dav1dPicture pic;
            memset(&pic, 0, sizeof(pic));
            if (dav1d_get_picture(ctx, &pic) < 0) break;
            handle(&pic);
            dav1d_picture_unref(&pic);
            if (failed) break;
        }
    }

    dav1d_data_unref(&data);

    if (session) {
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
    }
    dav1d_close(&ctx);

    if (failed || samples.count == 0) {
        stage(@"decode+encode", NO,
              [NSString stringWithFormat:@"frames=%d samples=%lu", frameIndex, (unsigned long)samples.count]);
        return nil;
    }

    *outW = width;
    *outH = height;
    stage(@"decode+encode", YES,
          [NSString stringWithFormat:@"%dx%d, %d frames", width, height, frameIndex]);
    return samples;
}

// MARK: - Mux

+ (BOOL)muxVideoSamples:(NSArray *)samples
              audioPath:(NSString *)audioPath
             outputPath:(NSString *)outputPath {
    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];

    NSError *error = nil;
    AVAssetWriter *writer =
        [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:outputPath]
                                  fileType:AVFileTypeMPEG4
                                     error:&error];
    if (!writer) {
        stage(@"mux", NO, error.localizedDescription ?: @"writer init failed");
        return NO;
    }

    CMSampleBufferRef first = (__bridge CMSampleBufferRef)samples.firstObject;
    CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(first);

    AVAssetWriterInput *videoInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                       outputSettings:nil
                                     sourceFormatHint:fmt];
    videoInput.expectsMediaDataInRealTime = NO;
    if ([writer canAddInput:videoInput]) [writer addInput:videoInput];

    // Audio is optional: a missing or unreadable track yields a video-only file
    // rather than failing the whole transcode.
    AVAssetReader *audioReader = nil;
    AVAssetReaderTrackOutput *audioOutput = nil;
    AVAssetWriterInput *audioInput = nil;

    if (audioPath) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:audioPath]];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (track) {
            audioReader = [AVAssetReader assetReaderWithAsset:asset error:nil];
            audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                                    outputSettings:@{ AVFormatIDKey: @(kAudioFormatLinearPCM) }];
            if ([audioReader canAddOutput:audioOutput]) [audioReader addOutput:audioOutput];

            NSDictionary *aac = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVSampleRateKey: @44100,
                AVNumberOfChannelsKey: @2,
                AVEncoderBitRateKey: @128000
            };
            audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                        outputSettings:aac];
            audioInput.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:audioInput]) [writer addInput:audioInput];
        }
    }

    if (![writer startWriting]) {
        stage(@"mux", NO, writer.error.localizedDescription ?: @"startWriting failed");
        return NO;
    }
    [writer startSessionAtSourceTime:kCMTimeZero];

    // Video: append every compressed sample in order. The readiness spin bails the
    // moment the writer leaves the writing state, so a silent failure ends the
    // append instead of spinning forever.
    for (id s in samples) {
        while (!videoInput.isReadyForMoreMediaData && writer.status == AVAssetWriterStatusWriting) {
            [NSThread sleepForTimeInterval:0.005];
        }
        if (writer.status != AVAssetWriterStatusWriting) break;
        [videoInput appendSampleBuffer:(__bridge CMSampleBufferRef)s];
    }
    [videoInput markAsFinished];

    // Audio: pull PCM from the reader, let the writer re-encode to AAC.
    if (audioReader && audioInput && [audioReader startReading]) {
        CMSampleBufferRef buf;
        while ((buf = [audioOutput copyNextSampleBuffer])) {
            while (!audioInput.isReadyForMoreMediaData && writer.status == AVAssetWriterStatusWriting) {
                [NSThread sleepForTimeInterval:0.005];
            }
            if (writer.status == AVAssetWriterStatusWriting) {
                [audioInput appendSampleBuffer:buf];
            }
            CFRelease(buf);
            if (writer.status != AVAssetWriterStatusWriting) break;
        }
        [audioInput markAsFinished];
    } else if (audioInput) {
        [audioInput markAsFinished];
    }

    // Bounded so a writer that never calls back cannot hang the pipeline.
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC)) != 0) {
        stage(@"mux", NO, @"finishWriting timed out");
        return NO;
    }

    BOOL ok = writer.status == AVAssetWriterStatusCompleted;
    stage(@"mux", ok, ok ? @"completed"
                         : (writer.error.localizedDescription ?: @"writer failed"));
    return ok;
}

// MARK: - Orchestration

+ (BOOL)transcodeVideoURL:(NSURL *)videoURL
                 audioURL:(NSURL *)audioURL
                      fps:(double)fps
             toOutputPath:(NSString *)outputPath
                 progress:(void (^)(NSString *))progress {
    if (fps < 1.0) fps = 30.0;

    NSString *videoPath = [self downloadToTempFile:videoURL extension:@"mp4"];
    if (!videoPath) { stage(@"download-video", NO, @"failed/timeout"); return NO; }
    stage(@"download-video", YES, nil);

    NSString *audioPath = [self downloadToTempFile:audioURL extension:@"mp4"];
    stage(@"download-audio", audioPath != nil, audioPath ? nil : @"none (video-only)");

    NSData *mp4 = [NSData dataWithContentsOfFile:videoPath];
    NSData *bitstream = [SCIMP4Demuxer av1BitstreamFromMP4:mp4];
    if (!bitstream) {
        stage(@"demux", NO, @"no av1C/mdat");
        [self cleanup:@[videoPath, audioPath ?: @""]];
        return NO;
    }
    stage(@"demux", YES, [NSString stringWithFormat:@"%lu bytes", (unsigned long)bitstream.length]);

    int w = 0, h = 0;
    NSArray *samples = [self encodeH264FromBitstream:bitstream fps:fps
                                           outWidth:&w outHeight:&h progress:progress];
    if (!samples) {
        [self cleanup:@[videoPath, audioPath ?: @""]];
        return NO;
    }

    if (progress) progress(@"mux");
    BOOL ok = [self muxVideoSamples:samples audioPath:audioPath outputPath:outputPath];

    [self cleanup:@[videoPath, audioPath ?: @""]];
    return ok;
}

+ (void)cleanup:(NSArray<NSString *> *)paths {
    for (NSString *p in paths) {
        if (p.length) [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
    }
}

@end
