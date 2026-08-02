//
//  SCIYTTransport.h
//  Albrhi for YouTube
//
//  Turns an MPEG-TS file into an .mp4, without carrying a media library to do it.
//
//  This exists because of one measured fact. YouTube 21.30.5 hands this build its video
//  as an HLS playlist whose parts end in seg.ts, and a device report said so exactly:
//  "94 entries, 94 URLs, no init, ends seg.ts". Fetching those parts always worked -- the
//  bytes arrived, the joining arrived, and then AVFoundation refused the result, because
//  iOS has never opened a local MPEG-TS file. Every tweak that solves this ships FFmpeg,
//  between two and nineteen megabytes of it, for what is in the end a container change.
//
//  It is a container change. The pictures inside are H.264 and the sound is AAC -- the
//  variant filter in SCIYTHLS guarantees that before a byte is fetched -- and iOS can
//  *write* both of those perfectly well. So the only part missing was reading the
//  transport stream: unwrapping 188-byte packets to recover the frames already inside.
//  Apple still builds the MP4; AVAssetWriter owns every index table in it, which is the
//  half of a muxer whose mistakes are silent.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@interface SCIYTTransport : NSObject

/// Whether a file is a transport stream, by looking rather than by extension.
///
/// The name a playlist gives a part is not evidence. This checks for the 0x47 sync byte
/// at the packet spacing the format defines, which is what actually distinguishes it.
+ (BOOL)isTransportStream:(NSURL *)file;

/// Rewrites a transport stream as an .mp4 alongside it.
///
/// On success the output URL is passed and the input is left alone -- deleting it is the
/// caller's business, since the caller is the one that knows whether it is a scratch file.
/// On failure the message is already localized and already specific: which of the two
/// tracks was missing, or which codec was found that this cannot carry.
+ (void)convert:(NSURL *)input
     completion:(void (^)(NSURL *output, NSString *error))completion;

@end
