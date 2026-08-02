#import "SCIYTTransport.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import <AVFoundation/AVFoundation.h>

// MPEG-TS is a fixed grid: 188 bytes per packet, each beginning with 0x47. Everything
// below is a matter of finding where in that grid the video actually starts.
static const NSUInteger kSCIPacketSize = 188;
static const uint8_t kSCISyncByte = 0x47;

// Stream types, from the PMT table that says what each stream inside the file is.
static const uint8_t kSCIStreamTypeH264 = 0x1B;
static const uint8_t kSCIStreamTypeAAC = 0x0F;

// Timestamps in a transport stream count at 90 kHz, and the counter is 33 bits wide.
// A long enough video reaches the end of it and starts again, which reads as time
// jumping backwards by a day; the wrap is undone rather than trusted.
static const int64_t kSCITimescale = 90000;
static const int64_t kSCITimestampWrap = 1LL << 33;

/// Where one frame lives in the scratch file, and when it is meant to be shown.
///
/// The frames themselves are written out as they are found, not kept. Holding a whole
/// video in memory to convert it is how a converter works on the twelve-second clip it
/// was tested against and gets killed on a half-hour one; a record is forty bytes, so
/// half an hour of them is a couple of megabytes.
typedef struct {
    int64_t pts;
    int64_t dts;
    uint64_t offset;
    uint32_t length;
    uint32_t sync;
} SCISample;


#pragma mark - Reading the grid

/// Undoes the 33-bit wrap, given the timestamp before it.
static int64_t SCIUnwrap(int64_t value, int64_t previous) {
    if (previous < 0) return value;

    // Only a jump most of the way back down the counter is a wrap. A small step backwards
    // is normal: B-frames are decoded before they are shown.
    while (value + (kSCITimestampWrap / 2) < previous) value += kSCITimestampWrap;
    return value;
}

/// The 33 bits of a timestamp, spread across five bytes with markers in between.
static int64_t SCIReadTimestamp(const uint8_t *bytes) {
    return ((int64_t)(bytes[0] & 0x0E) << 29)
         | ((int64_t)bytes[1] << 22)
         | ((int64_t)(bytes[2] & 0xFE) << 14)
         | ((int64_t)bytes[3] << 7)
         | ((int64_t)(bytes[4] & 0xFE) >> 1);
}

/// Where the packets begin.
///
/// Not assumed to be zero. A playlist's first part can carry a partial packet, and lining
/// up on the first 0x47 that repeats at the right spacing costs one loop and removes a
/// whole class of "it worked on that video" failure.
static NSInteger SCIFindSync(const uint8_t *bytes, NSUInteger length) {
    NSUInteger limit = MIN(length, kSCIPacketSize * 4);

    for (NSUInteger start = 0; start < limit; start++) {
        BOOL aligned = YES;

        for (int probe = 1; probe <= 3; probe++) {
            NSUInteger at = start + (kSCIPacketSize * probe);
            if (at >= length) break;
            if (bytes[at] != kSCISyncByte) { aligned = NO; break; }
        }

        if (bytes[start] == kSCISyncByte && aligned) return (NSInteger)start;
    }
    return -1;
}


#pragma mark - Elementary streams

/// One track being recovered: the frames found so far, and what it took to describe them.
@interface SCIYTElementary : NSObject
@property (nonatomic) uint8_t streamType;
@property (nonatomic, strong) NSMutableData *pending;      ///< the PES being gathered
@property (nonatomic, strong) NSMutableData *index;        ///< SCISample records
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;
@property (nonatomic) int64_t lastPTS;
@property (nonatomic) int64_t lastDTS;
@property (nonatomic) uint32_t sampleRate;
@property (nonatomic) uint32_t channels;
@property (nonatomic) uint8_t profile;
@property (nonatomic) int64_t audioFrames;                 ///< AAC frames emitted so far
@property (nonatomic) int64_t audioStart;                  ///< in the track's own timescale
@property (nonatomic) BOOL audioStarted;

- (NSUInteger)count;
- (void)addSample:(SCISample)sample;
@end

@implementation SCIYTElementary

- (instancetype)init {
    if ((self = [super init])) {
        _pending = [NSMutableData data];
        _index = [NSMutableData data];
        _lastPTS = -1;
        _lastDTS = -1;
    }
    return self;
}

- (NSUInteger)count { return self.index.length / sizeof(SCISample); }

- (void)addSample:(SCISample)sample {
    [self.index appendBytes:&sample length:sizeof(sample)];
}

@end


@implementation SCIYTTransport

+ (BOOL)isTransportStream:(NSURL *)file {
    NSData *head = [NSData dataWithContentsOfURL:file
                                         options:NSDataReadingMappedIfSafe
                                           error:nil];
    if (head.length < kSCIPacketSize * 4) return NO;
    return SCIFindSync(head.bytes, MIN(head.length, kSCIPacketSize * 8)) >= 0;
}


#pragma mark - Pass one: unwrap the packets

/// Reads the PMT and records which stream is which.
///
/// The table says what is inside rather than what the file is named, which is the only
/// answer worth having: a playlist that quietly served HEVC would otherwise convert into
/// a file that does not play, and this is where that is caught and named.
+ (void)readPMT:(const uint8_t *)payload
         length:(NSUInteger)length
          into:(NSMutableDictionary<NSNumber *, SCIYTElementary *> *)streams {
    if (length < 12) return;

    NSUInteger pointer = payload[0];
    if (1 + pointer >= length) return;

    const uint8_t *section = payload + 1 + pointer;
    NSUInteger available = length - 1 - pointer;
    if (available < 12 || section[0] != 0x02) return;

    NSUInteger sectionLength = ((section[1] & 0x0F) << 8) | section[2];
    NSUInteger end = MIN(3 + sectionLength, available);
    if (end < 4) return;
    end -= 4;   // the checksum at the tail is not a stream entry

    NSUInteger infoLength = ((section[10] & 0x0F) << 8) | section[11];
    NSUInteger at = 12 + infoLength;

    while (at + 5 <= end) {
        uint8_t type = section[at];
        uint16_t pid = ((section[at + 1] & 0x1F) << 8) | section[at + 2];
        NSUInteger esInfo = ((section[at + 3] & 0x0F) << 8) | section[at + 4];

        if (!streams[@(pid)] && (type == kSCIStreamTypeH264 || type == kSCIStreamTypeAAC)) {
            SCIYTElementary *stream = [[SCIYTElementary alloc] init];
            stream.streamType = type;
            streams[@(pid)] = stream;
        }

        at += 5 + esInfo;
    }
}

/// Reads the PAT and returns the PID the PMT will arrive on.
+ (uint16_t)readPAT:(const uint8_t *)payload length:(NSUInteger)length {
    if (length < 13) return 0;

    NSUInteger pointer = payload[0];
    if (1 + pointer + 12 > length) return 0;

    const uint8_t *section = payload + 1 + pointer;
    if (section[0] != 0x00) return 0;

    return ((section[10] & 0x1F) << 8) | section[11];
}

/// Splits an H.264 access unit into its parts and writes it in the form MP4 wants.
///
/// A transport stream separates frames with start codes; an MP4 prefixes each with its
/// length. The parameter sets are lifted out rather than copied through -- they belong in
/// the track description, and Apple puts them there.
+ (NSData *)convertAccessUnit:(const uint8_t *)bytes
                       length:(NSUInteger)length
                       stream:(SCIYTElementary *)stream
                      keyframe:(BOOL *)keyframe {
    NSMutableData *output = [NSMutableData dataWithCapacity:length];
    NSUInteger at = 0;

    while (at + 3 <= length) {
        if (!(bytes[at] == 0x00 && bytes[at + 1] == 0x00 &&
              (bytes[at + 2] == 0x01 ||
               (bytes[at + 2] == 0x00 && at + 4 <= length && bytes[at + 3] == 0x01)))) {
            at++;
            continue;
        }

        NSUInteger headerSize = (bytes[at + 2] == 0x01) ? 3 : 4;
        NSUInteger start = at + headerSize;
        if (start >= length) break;

        // Where the next start code is, which is where this one ends.
        NSUInteger next = start;
        while (next + 3 <= length) {
            if (bytes[next] == 0x00 && bytes[next + 1] == 0x00 &&
                (bytes[next + 2] == 0x01 ||
                 (bytes[next + 2] == 0x00 && next + 4 <= length && bytes[next + 3] == 0x01))) {
                break;
            }
            next++;
        }
        if (next + 3 > length) next = length;

        NSUInteger size = next - start;
        at = next;
        if (!size) continue;

        uint8_t type = bytes[start] & 0x1F;

        if (type == 7) { if (!stream.sps) stream.sps = [NSData dataWithBytes:bytes + start length:size]; continue; }
        if (type == 8) { if (!stream.pps) stream.pps = [NSData dataWithBytes:bytes + start length:size]; continue; }
        if (type == 9) continue;   // the access unit delimiter carries nothing

        if (type == 5) *keyframe = YES;

        uint32_t prefix = CFSwapInt32HostToBig((uint32_t)size);
        [output appendBytes:&prefix length:sizeof(prefix)];
        [output appendBytes:bytes + start length:size];
    }

    return output;
}

/// Reads the ADTS headers wrapping each block of sound and writes the sound alone.
+ (void)convertADTS:(const uint8_t *)bytes
             length:(NSUInteger)length
             stream:(SCIYTElementary *)stream
             handle:(NSFileHandle *)scratch
             offset:(uint64_t *)offset {
    static const uint32_t rates[16] = {
        96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050,
        16000, 12000, 11025,  8000,  7350,     0,     0,     0
    };

    NSUInteger at = 0;

    while (at + 7 <= length) {
        if (!(bytes[at] == 0xFF && (bytes[at + 1] & 0xF0) == 0xF0)) { at++; continue; }

        NSUInteger frameLength = ((NSUInteger)(bytes[at + 3] & 0x03) << 11)
                               | ((NSUInteger)bytes[at + 4] << 3)
                               | ((NSUInteger)(bytes[at + 5] & 0xE0) >> 5);

        NSUInteger headerSize = (bytes[at + 1] & 0x01) ? 7 : 9;
        if (frameLength <= headerSize || at + frameLength > length) break;

        if (!stream.sampleRate) {
            stream.profile = (bytes[at + 2] & 0xC0) >> 6;
            stream.sampleRate = rates[(bytes[at + 2] & 0x3C) >> 2];
            stream.channels = (uint32_t)(((bytes[at + 2] & 0x01) << 2) | ((bytes[at + 3] & 0xC0) >> 6));
            if (!stream.sampleRate || !stream.channels) return;
        }

        // Sound is counted in its own frames rather than in the stream's clock. Every AAC
        // block is exactly 1024 samples long, so counting them is exact where converting
        // a 90 kHz timestamp per block accumulates a drift you can hear by the end.
        if (!stream.audioStarted) {
            stream.audioStart = (stream.lastPTS > 0)
                ? (stream.lastPTS * (int64_t)stream.sampleRate / kSCITimescale) : 0;
            stream.audioStarted = YES;
        }

        NSUInteger payload = frameLength - headerSize;
        [scratch writeData:[NSData dataWithBytes:bytes + at + headerSize length:payload]];

        SCISample sample;
        sample.pts = stream.audioStart + (stream.audioFrames * 1024);
        sample.dts = sample.pts;
        sample.offset = *offset;
        sample.length = (uint32_t)payload;
        sample.sync = 1;
        [stream addSample:sample];

        *offset += payload;
        stream.audioFrames += 1;
        at += frameLength;
    }
}

/// Closes off the PES gathered for one stream and records the frame inside it.
+ (void)flush:(SCIYTElementary *)stream
       handle:(NSFileHandle *)scratch
       offset:(uint64_t *)offset {
    if (!stream.pending.length) return;

    // Copied out before the buffer is emptied. Reading -bytes and then shortening the
    // same NSMutableData leaves the pointer pointing at whatever it pleases; it happens to
    // survive on small buffers, which is the worst way for it to be wrong.
    NSData *packet = [stream.pending copy];
    [stream.pending setLength:0];

    const uint8_t *bytes = packet.bytes;
    NSUInteger length = packet.length;

    if (length < 9) return;
    if (!(bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01)) return;

    NSUInteger headerLength = bytes[8];
    NSUInteger payloadAt = 9 + headerLength;
    if (payloadAt >= length) return;

    uint8_t flags = (bytes[7] & 0xC0) >> 6;
    if (flags & 0x02) {
        if (payloadAt < 14) return;
        stream.lastPTS = SCIUnwrap(SCIReadTimestamp(bytes + 9), stream.lastPTS);
        stream.lastDTS = (flags == 0x03 && payloadAt >= 19)
            ? SCIUnwrap(SCIReadTimestamp(bytes + 14), stream.lastDTS)
            : stream.lastPTS;
    }

    const uint8_t *payload = bytes + payloadAt;
    NSUInteger payloadLength = length - payloadAt;

    if (stream.streamType == kSCIStreamTypeAAC) {
        [self convertADTS:payload length:payloadLength stream:stream handle:scratch offset:offset];
        return;
    }

    BOOL keyframe = NO;
    NSData *unit = [self convertAccessUnit:payload length:payloadLength stream:stream keyframe:&keyframe];
    if (!unit.length) return;

    [scratch writeData:unit];

    SCISample sample;
    sample.pts = stream.lastPTS;
    sample.dts = stream.lastDTS;
    sample.offset = *offset;
    sample.length = (uint32_t)unit.length;
    sample.sync = keyframe ? 1 : 0;
    [stream addSample:sample];

    *offset += unit.length;
}

/// Walks the whole file once, filling the scratch file and the two indexes.
+ (NSDictionary<NSNumber *, SCIYTElementary *> *)demux:(NSData *)input
                                                handle:(NSFileHandle *)scratch {
    NSMutableDictionary<NSNumber *, SCIYTElementary *> *streams = [NSMutableDictionary dictionary];

    const uint8_t *bytes = input.bytes;
    NSUInteger length = input.length;

    NSInteger start = SCIFindSync(bytes, length);
    if (start < 0) return streams;

    uint16_t pmtPID = 0;
    uint64_t offset = 0;

    for (NSUInteger at = (NSUInteger)start; at + kSCIPacketSize <= length; at += kSCIPacketSize) {
        const uint8_t *packet = bytes + at;
        if (packet[0] != kSCISyncByte) {
            // One bad packet is not a broken file -- a part can arrive short. Line up again
            // rather than abandoning ninety-three good segments over one.
            NSInteger again = SCIFindSync(packet, length - at);
            if (again < 0) break;
            at += (NSUInteger)again;
            at -= kSCIPacketSize;
            continue;
        }

        uint16_t pid = ((packet[1] & 0x1F) << 8) | packet[2];
        BOOL unitStart = (packet[1] & 0x40) != 0;
        uint8_t adaptation = (packet[3] & 0x30) >> 4;

        NSUInteger payloadAt = 4;
        if (adaptation == 0x02) continue;                 // adaptation only, no payload
        if (adaptation == 0x03) payloadAt += 1 + packet[4];
        if (payloadAt >= kSCIPacketSize) continue;

        const uint8_t *payload = packet + payloadAt;
        NSUInteger payloadLength = kSCIPacketSize - payloadAt;

        if (pid == 0) {
            if (unitStart && !pmtPID) pmtPID = [self readPAT:payload length:payloadLength];
            continue;
        }

        if (pid == pmtPID) {
            if (unitStart) [self readPMT:payload length:payloadLength into:streams];
            continue;
        }

        SCIYTElementary *stream = streams[@(pid)];
        if (!stream) continue;

        if (unitStart) [self flush:stream handle:scratch offset:&offset];
        [stream.pending appendBytes:payload length:payloadLength];
    }

    for (SCIYTElementary *stream in streams.allValues) {
        [self flush:stream handle:scratch offset:&offset];
    }

    return streams;
}

/// The length of an ID3 tag at `at`, or 0 if there is not one there.
///
/// Validated rather than matched on the three letters: those three bytes turn up in a few
/// megabytes of audio by chance about one time in six, and a false one would read a length
/// out of the audio itself and skip forward by it -- throwing away the rest of the track
/// without a word.
static NSUInteger SCIID3Length(const uint8_t *bytes, NSUInteger at, NSUInteger length) {
    if (at + 10 > length) return 0;
    if (bytes[at] != 'I' || bytes[at + 1] != 'D' || bytes[at + 2] != '3') return 0;
    if (bytes[at + 3] == 0xFF || bytes[at + 4] == 0xFF) return 0;       // the version bytes

    // The length is four syncsafe bytes: seven bits each, the top bit always clear so it
    // can never look like a frame sync. Five constraints together, which chance does not
    // meet by accident.
    for (int i = 6; i < 10; i++) { if (bytes[at + i] & 0x80) return 0; }

    NSUInteger size = ((NSUInteger)bytes[at + 6] << 21) | ((NSUInteger)bytes[at + 7] << 14)
                    | ((NSUInteger)bytes[at + 8] << 7)  |  (NSUInteger)bytes[at + 9];

    return (at + 10 + size <= length) ? 10 + size : 0;
}

/// The same as `demux:`, for audio that arrives with no wrapper at all.
///
/// An HLS audio rendition need not be a transport stream. "Packed audio" is the bare AAC
/// frames with an ID3 tag in front of each part and nothing else around them -- which is
/// what this build serves, and what 0.12.2 handed to AVFoundation by renaming the file.
/// Renaming was not enough: twenty-six tags sit inside the joined file, not just at its
/// start, and that is a shape a reader may make no sense of.
///
/// Nothing new is needed to read it. The frames are identical to the ones the transport
/// path pulls out of PES packets, so the same parser takes them -- only the tags between
/// the runs have to be stepped over first.
+ (NSDictionary<NSNumber *, SCIYTElementary *> *)packedAudio:(NSData *)input
                                                      handle:(NSFileHandle *)scratch {
    SCIYTElementary *stream = [[SCIYTElementary alloc] init];
    stream.streamType = kSCIStreamTypeAAC;

    const uint8_t *bytes = input.bytes;
    NSUInteger length = input.length;
    NSUInteger at = 0;
    uint64_t offset = 0;

    while (at < length) {
        NSUInteger tag = SCIID3Length(bytes, at, length);
        if (tag) { at += tag; continue; }

        NSUInteger end = at + 1;
        while (end < length && !SCIID3Length(bytes, end, length)) end++;

        [self convertADTS:bytes + at length:end - at stream:stream handle:scratch offset:&offset];
        at = end;
    }

    return [stream count] ? @{@(0): stream} : @{};
}


#pragma mark - Pass two: hand the frames to Apple

/// One frame, wrapped the way AVAssetWriter wants it.
+ (CMSampleBufferRef)bufferFor:(SCISample)sample
                         bytes:(const uint8_t *)bytes
                        format:(CMFormatDescriptionRef)format
                        timing:(CMSampleTimingInfo)timing CF_RETURNS_RETAINED {
    CMBlockBufferRef block = NULL;
    if (CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, sample.length,
                                           kCFAllocatorDefault, NULL, 0, sample.length,
                                           kCMBlockBufferAssureMemoryNowFlag, &block) != noErr) {
        return NULL;
    }

    if (CMBlockBufferReplaceDataBytes(bytes + sample.offset, block, 0, sample.length) != noErr) {
        CFRelease(block);
        return NULL;
    }

    CMSampleBufferRef buffer = NULL;
    size_t size = sample.length;
    OSStatus status = CMSampleBufferCreate(kCFAllocatorDefault, block, TRUE, NULL, NULL,
                                           format, 1, 1, &timing, 1, &size, &buffer);
    CFRelease(block);

    if (status != noErr) return NULL;

    if (!sample.sync) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, YES);
        if (attachments && CFArrayGetCount(attachments)) {
            CFMutableDictionaryRef entry =
                (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(entry, kCMSampleAttachmentKey_NotSync, kCFBooleanTrue);
        }
    }

    return buffer;
}

/// Feeds one track's frames in, waiting whenever the writer says it is busy.
+ (BOOL)writeTrack:(SCIYTElementary *)stream
             input:(AVAssetWriterInput *)input
            writer:(AVAssetWriter *)writer
            format:(CMFormatDescriptionRef)format
             bytes:(const uint8_t *)bytes
         timescale:(int32_t)timescale {
    const SCISample *samples = stream.index.bytes;
    NSUInteger count = [stream count];

    for (NSUInteger i = 0; i < count; i++) {
        while (!input.isReadyForMoreMediaData) {
            if (writer.status != AVAssetWriterStatusWriting) return NO;
            [NSThread sleepForTimeInterval:0.01];
        }

        // A frame lasts until the next one begins. The last one is given the length of the
        // one before it, there being nothing after it to measure against.
        int64_t span = (i + 1 < count) ? (samples[i + 1].dts - samples[i].dts)
                     : (i > 0 ? (samples[i].dts - samples[i - 1].dts) : timescale / 30);
        if (span <= 0) span = 1;

        CMSampleTimingInfo timing;
        timing.duration = CMTimeMake(span, timescale);
        timing.presentationTimeStamp = CMTimeMake(samples[i].pts, timescale);
        timing.decodeTimeStamp = CMTimeMake(samples[i].dts, timescale);

        CMSampleBufferRef buffer = [self bufferFor:samples[i] bytes:bytes format:format timing:timing];
        if (!buffer) continue;

        BOOL appended = [input appendSampleBuffer:buffer];
        CFRelease(buffer);
        if (!appended) return NO;
    }

    [input markAsFinished];
    return YES;
}

+ (void)convert:(NSURL *)input completion:(void (^)(NSURL *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        void (^finish)(NSURL *, NSString *) = ^(NSURL *output, NSString *error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(output, error); });
        };

        NSData *source = [NSData dataWithContentsOfURL:input
                                               options:NSDataReadingMappedIfSafe
                                                 error:nil];
        if (!source.length) { finish(nil, SCILocalized(@"dl_ts_empty")); return; }

        NSString *scratchPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"raw"]];
        [[NSFileManager defaultManager] createFileAtPath:scratchPath contents:nil attributes:nil];

        NSFileHandle *scratch = [NSFileHandle fileHandleForWritingAtPath:scratchPath];
        if (!scratch) { finish(nil, SCILocalized(@"dl_ts_empty")); return; }

        // Which of the two shapes arrived. Both end in the same place -- a table of frames
        // for Apple to index -- and only the unwrapping differs.
        NSDictionary<NSNumber *, SCIYTElementary *> *streams =
            [self isTransportStream:input] ? [self demux:source handle:scratch]
                                           : [self packedAudio:source handle:scratch];
        [scratch closeFile];

        SCIYTElementary *video = nil, *audio = nil;
        for (SCIYTElementary *stream in streams.allValues) {
            if (stream.streamType == kSCIStreamTypeH264 && [stream count]) video = stream;
            if (stream.streamType == kSCIStreamTypeAAC && [stream count]) audio = stream;
        }

        // What the stream actually declared, in the report.
        //
        // Every way this can end up silent is invisible from outside: a PMT with no audio
        // entry, an audio type this does not read, a stream registered but carrying no
        // frames. All three produce the same file, and the file says nothing. One line
        // costs nothing and tells the three apart without a second attempt.
        NSMutableArray<NSString *> *declared = [NSMutableArray array];
        for (SCIYTElementary *stream in streams.allValues) {
            [declared addObject:[NSString stringWithFormat:@"0x%02X×%lu",
                stream.streamType, (unsigned long)[stream count]]];
        }
        [SCIYTDiagnostics recordStreamAttempt:[NSString stringWithFormat:@"ts: %@",
            declared.count ? [declared componentsJoinedByString:@", "] : @"no streams"]];

        NSString *(^fail)(NSString *) = ^NSString *(NSString *key) {
            [[NSFileManager defaultManager] removeItemAtPath:scratchPath error:nil];
            return SCILocalized(key);
        };

        // An audio-only stream is a legitimate input, not a broken one.
        //
        // It is what an HLS audio rendition is made of, and refusing it here -- which is
        // what "no video" used to mean -- is why 0.11.0 could not fetch the sound that a
        // manifest kept separate from the pictures. Either track alone is convertible;
        // only neither is a failure.
        BOOL hasVideo = (video && video.sps.length && video.pps.length);
        if (!hasVideo && !audio) { finish(nil, fail(@"dl_ts_no_video")); return; }

        NSData *frames = [NSData dataWithContentsOfFile:scratchPath
                                                options:NSDataReadingMappedIfSafe
                                                  error:nil];
        if (!frames.length) { finish(nil, fail(@"dl_ts_no_video")); return; }

        // The picture description, built from the two parameter sets lifted out of the
        // stream. Apple writes them into the track, which is where a player looks.
        CMFormatDescriptionRef videoFormat = NULL;
        if (hasVideo) {
            const uint8_t *parameterSets[2] = { video.sps.bytes, video.pps.bytes };
            const size_t parameterSizes[2] = { video.sps.length, video.pps.length };

            if (CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2,
                    parameterSets, parameterSizes, 4, &videoFormat) != noErr) {
                videoFormat = NULL;
            }
        }
        if (!videoFormat && !audio) { finish(nil, fail(@"dl_ts_no_video")); return; }

        CMFormatDescriptionRef audioFormat = NULL;
        if (audio && audio.sampleRate) {
            AudioStreamBasicDescription description = {0};
            description.mSampleRate = audio.sampleRate;
            description.mFormatID = kAudioFormatMPEG4AAC;
            description.mChannelsPerFrame = audio.channels;
            description.mFramesPerPacket = 1024;

            // The two bytes that say which flavour of AAC this is: object type, rate and
            // channel count, packed the way the format defines.
            static const uint32_t rates[16] = {
                96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050,
                16000, 12000, 11025,  8000,  7350,     0,     0,     0
            };
            uint8_t rateIndex = 4;
            for (uint8_t i = 0; i < 13; i++) {
                if (rates[i] == audio.sampleRate) { rateIndex = i; break; }
            }

            uint16_t config = (uint16_t)(((audio.profile + 1) << 11)
                                       | (rateIndex << 7)
                                       | (audio.channels << 3));
            uint8_t cookie[2] = { (uint8_t)(config >> 8), (uint8_t)(config & 0xFF) };

            if (CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &description, 0, NULL,
                    sizeof(cookie), cookie, NULL, &audioFormat) != noErr) {
                audioFormat = NULL;
            }
        }

        NSURL *output = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:
                [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]]];

        NSError *writerError = nil;
        AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:output
                                                          fileType:AVFileTypeMPEG4
                                                             error:&writerError];
        if (!writer) {
            if (videoFormat) CFRelease(videoFormat);
            if (audioFormat) CFRelease(audioFormat);
            finish(nil, fail(@"dl_ts_write_failed"));
            return;
        }

        AVAssetWriterInput *videoInput = nil;
        if (videoFormat) {
            videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                            outputSettings:nil
                                                          sourceFormatHint:videoFormat];
            videoInput.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:videoInput]) [writer addInput:videoInput]; else videoInput = nil;
        }

        AVAssetWriterInput *audioInput = nil;
        if (audioFormat && [audio count]) {
            audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                            outputSettings:nil
                                                          sourceFormatHint:audioFormat];
            audioInput.expectsMediaDataInRealTime = NO;
            if ([writer canAddInput:audioInput]) [writer addInput:audioInput]; else audioInput = nil;
        }

        if (!videoInput && !audioInput) {
            if (videoFormat) CFRelease(videoFormat);
            if (audioFormat) CFRelease(audioFormat);
            finish(nil, fail(@"dl_ts_write_failed"));
            return;
        }

        [writer startWriting];

        // Whichever track exists starts the session, in its own timescale. For an
        // audio-only rendition there is no video index to read a first sample from, and
        // reading one anyway is a null dereference rather than a wrong number.
        if (videoInput) {
            const SCISample *first = video.index.bytes;
            [writer startSessionAtSourceTime:CMTimeMake(first[0].dts, (int32_t)kSCITimescale)];
        } else {
            const SCISample *first = audio.index.bytes;
            [writer startSessionAtSourceTime:CMTimeMake(first[0].dts, (int32_t)audio.sampleRate)];
        }

        const uint8_t *bytes = frames.bytes;
        BOOL ok = YES;

        if (videoInput) {
            ok = [self writeTrack:video input:videoInput writer:writer format:videoFormat
                            bytes:bytes timescale:(int32_t)kSCITimescale];
        }

        if (ok && audioInput) {
            ok = [self writeTrack:audio input:audioInput writer:writer format:audioFormat
                            bytes:bytes timescale:(int32_t)audio.sampleRate];
        }

        SCILogV(@"ts: %lu video frames, %lu audio frames, joined %@",
                (unsigned long)[video count], (unsigned long)[audio count],
                ok ? @"cleanly" : @"with a refusal");

        if (!ok) {
            [writer cancelWriting];
            if (videoFormat) CFRelease(videoFormat);
            if (audioFormat) CFRelease(audioFormat);
            finish(nil, fail(@"dl_ts_write_failed"));
            return;
        }

        [writer finishWritingWithCompletionHandler:^{
            AVAssetWriterStatus status = writer.status;
            if (videoFormat) CFRelease(videoFormat);
            if (audioFormat) CFRelease(audioFormat);
            [[NSFileManager defaultManager] removeItemAtPath:scratchPath error:nil];

            if (status == AVAssetWriterStatusCompleted) {
                finish(output, nil);
            } else {
                SCILogV(@"ts: writer refused — %@", writer.error.localizedDescription);
                [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                finish(nil, SCILocalized(@"dl_ts_write_failed"));
            }
        }];
    });
}

@end
