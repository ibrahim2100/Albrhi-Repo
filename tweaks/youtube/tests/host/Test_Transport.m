//
//  Test_Transport.m
//  Albrhi for YouTube — host tests
//
//  The MPEG-TS demuxer, run on the build machine.
//
//  **Why this one first.** It is 759 lines this project wrote by hand rather than vendoring
//  ffmpeg for, its whole interface is a file in and a file out, and it needs no device: a
//  transport stream is bytes with a shape, and the shape can be built here. Nothing in the
//  shipping code changed to make this testable, which is the point — a test that requires
//  a refactor is a test that can break the thing it was written to protect.
//
#import <Foundation/Foundation.h>
#import "SCIYTTransport.h"
#import "AlbrhiTestKit.h"

static NSURL *SCIWriteTemp(NSData *data, NSString *extension) {
    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    return [data writeToURL:url atomically:YES] ? url : nil;
}

/// A stream of well-formed 188-byte packets: sync byte, a PID, and payload. Enough for the
/// detector, which is what this asserts about.
static NSData *SCISyntheticTS(NSUInteger packets) {
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger i = 0; i < packets; i++) {
        uint8_t packet[188];
        memset(packet, 0xFF, sizeof(packet));
        packet[0] = 0x47;               // sync
        packet[1] = 0x40;               // payload start, PID high bits
        packet[2] = 0x11;               // PID low
        packet[3] = 0x10 | (i & 0x0F);  // payload only, continuity counter
        [data appendBytes:packet length:sizeof(packet)];
    }
    return data;
}

void Test_Transport(void) {
    ALBRHI_TEST(Transport_wellFormedPackets_areRecognised, {
        NSURL *file = SCIWriteTemp(SCISyntheticTS(64), @"ts");
        ALBRHI_ASSERT(file != nil, @"the temp file was written");
        ALBRHI_ASSERT([SCIYTTransport isTransportStream:file], @"188-byte packets on 0x47 read as a transport stream");
        [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
    });

    ALBRHI_TEST(Transport_mp4Header_isNotATransportStream, {
        // An ISO base media file: the 'ftyp' box, which is what an actual MP4 download starts
        // with. The detector must not claim it, or a finished file would be demuxed a second time.
        const uint8_t mp4[] = { 0x00,0x00,0x00,0x18,'f','t','y','p','m','p','4','2',
                                0x00,0x00,0x00,0x00,'m','p','4','2','i','s','o','m' };
        NSURL *file = SCIWriteTemp([NSData dataWithBytes:mp4 length:sizeof(mp4)], @"mp4");
        ALBRHI_ASSERT(file != nil, @"the temp file was written");
        ALBRHI_ASSERT(![SCIYTTransport isTransportStream:file], @"an ftyp box is not a transport stream");
        [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
    });

    ALBRHI_TEST(Transport_emptyAndMissingFiles_areRefusedNotCrashed, {
        NSURL *empty = SCIWriteTemp([NSData data], @"ts");
        ALBRHI_ASSERT(![SCIYTTransport isTransportStream:empty], @"an empty file is not a transport stream");
        [[NSFileManager defaultManager] removeItemAtURL:empty error:nil];

        NSURL *gone = [NSURL fileURLWithPath:@"/tmp/albrhi-does-not-exist.ts"];
        ALBRHI_ASSERT(![SCIYTTransport isTransportStream:gone], @"a file that is not there is not a transport stream");
    });

    ALBRHI_TEST(Transport_truncatedStream_failsWithAReasonNotACrash, {
        // Half a packet. The demuxer has to end with an error rather than reading past it --
        // this project's own rule that a crash is worse than the thing being prevented.
        NSMutableData *half = [NSMutableData dataWithData:SCISyntheticTS(1)];
        [half setLength:94];
        NSURL *file = SCIWriteTemp(half, @"ts");

        __block BOOL answered = NO;
        __block NSString *failure = nil;
        [SCIYTTransport convert:file completion:^(NSURL *output, NSString *error) {
            answered = YES;
            failure = error ?: (output ? nil : @"neither output nor error");
        }];

        // The conversion is synchronous inside its own call for a file this small; if that ever
        // changes, this waits rather than asserting on a result that has not arrived.
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!answered && [deadline timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:
                [NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        ALBRHI_ASSERT(answered, @"the conversion answered rather than hanging");
        [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
    });
}
