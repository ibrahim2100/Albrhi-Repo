#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Pulls the raw AV1 bitstream out of an ISO-BMFF (mp4) container so dav1d can
/// decode it. dav1d wants OBUs, not an mp4, and iOS 16.1 cannot demux an AV1
/// track itself, so this does the unwrapping directly.
///
/// It does not walk the full sample table. AV1 samples in mp4 are self-sized,
/// temporal-delimiter-separated OBUs, so the concatenated `mdat` payload is
/// already a valid bitstream; only the sequence header, which lives in the
/// `av1C` box rather than the samples, has to be recovered and prepended.
///
@interface SCIMP4Demuxer : NSObject

/// The decodable AV1 bitstream (config OBUs followed by every sample), or nil if
/// the file carries no `av1C`/`mdat` — i.e. it is not the AV1 mp4 we expected.
+ (nullable NSData *)av1BitstreamFromMP4:(NSData *)mp4;

@end

NS_ASSUME_NONNULL_END
