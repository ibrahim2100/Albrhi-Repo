#import "SCIMP4Demuxer.h"

@implementation SCIMP4Demuxer

// Reads a big-endian uint32 at offset, or 0 if it would run off the end.
static uint32_t be32(const uint8_t *p, NSUInteger len, NSUInteger off) {
    if (off + 4 > len) return 0;
    return ((uint32_t)p[off] << 24) | ((uint32_t)p[off + 1] << 16)
         | ((uint32_t)p[off + 2] << 8) | (uint32_t)p[off + 3];
}

static uint64_t be64(const uint8_t *p, NSUInteger len, NSUInteger off) {
    if (off + 8 > len) return 0;
    return ((uint64_t)be32(p, len, off) << 32) | (uint64_t)be32(p, len, off + 4);
}

// Collects the payload byte-ranges of every top-level box of a given type.
// Box: size(4) type(4) [largesize(8) when size==1] payload. size==0 runs to EOF.
+ (NSArray<NSValue *> *)topLevelBoxes:(const uint8_t *)p length:(NSUInteger)len type:(const char *)type {
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSUInteger off = 0;

    while (off + 8 <= len) {
        uint64_t size = be32(p, len, off);
        NSUInteger header = 8;

        if (size == 1) {
            size = be64(p, len, off + 8);
            header = 16;
        } else if (size == 0) {
            size = len - off;
        }

        // A malformed size that does not advance would loop forever.
        if (size < header || off + size > len) break;

        if (memcmp(p + off + 4, type, 4) == 0) {
            NSRange payload = NSMakeRange(off + header, (NSUInteger)size - header);
            [ranges addObject:[NSValue valueWithRange:payload]];
        }

        off += (NSUInteger)size;
    }

    return ranges;
}

// The AV1CodecConfigurationRecord's configOBUs — the sequence header — begin
// after its 4-byte fixed header. 'av1C' is located by tag search rather than by
// descending stsd→av01: getting those fixed-field offsets exactly right is far
// more error-prone than matching a rare four-byte tag, and the record's own size
// field validates the hit.
+ (NSData *)configOBUs:(const uint8_t *)p length:(NSUInteger)len {
    for (NSUInteger i = 4; i + 4 <= len; i++) {
        if (memcmp(p + i, "av1C", 4) != 0) continue;

        uint32_t boxSize = be32(p, len, i - 4);      // size precedes the tag
        if (boxSize < 12) continue;                   // 8 box header + 4 fixed

        NSUInteger payloadStart = i + 4 + 4;          // past tag, past fixed header
        NSUInteger payloadLen = boxSize - 8 - 4;
        if (payloadStart + payloadLen > len) continue;

        if (payloadLen == 0) return [NSData data];
        return [NSData dataWithBytes:p + payloadStart length:payloadLen];
    }
    return nil;
}

+ (NSData *)av1BitstreamFromMP4:(NSData *)mp4 {
    if (mp4.length < 16) return nil;

    const uint8_t *p = mp4.bytes;
    NSUInteger len = mp4.length;

    NSData *config = [self configOBUs:p length:len];
    NSArray<NSValue *> *mdats = [self topLevelBoxes:p length:len type:"mdat"];
    if (!config || mdats.count == 0) return nil;

    NSMutableData *stream = [NSMutableData dataWithData:config];
    for (NSValue *v in mdats) {
        NSRange r = v.rangeValue;
        [stream appendBytes:p + r.location length:r.length];
    }

    return stream.length > config.length ? stream : nil;
}

@end
