#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Turns Instagram's AV1 video ladder into an H.264 file iOS can save.
///
/// Instagram serves its high-quality renditions as AV1 with separate xHE-AAC
/// audio; iOS 16.1 can neither decode nor save either. This downloads both
/// streams, decodes the AV1 with dav1d, re-encodes to H.264 with VideoToolbox,
/// transcodes the audio to AAC and muxes the result — all on device, so nothing
/// is sent anywhere.
///
/// Every stage reports to the diagnostics page. Because the whole pipeline is
/// untestable off-device, a failure has to name the stage it happened in rather
/// than surface as a blank video; the caller falls back to the progressive
/// download so the user always gets a file.
///
@interface SCIAV1Transcoder : NSObject

/// Downloads, transcodes and muxes to `outputPath`. Blocking — call off the main
/// thread. Returns NO on any failure, having recorded which stage failed; the
/// caller should then fall back to the progressive rendition.
///
/// `audioURL` may be nil, in which case the output is video-only.
+ (BOOL)transcodeVideoURL:(NSURL *)videoURL
                 audioURL:(nullable NSURL *)audioURL
                      fps:(double)fps
             toOutputPath:(NSString *)outputPath;

@end

NS_ASSUME_NONNULL_END
