#import "SCIYTMDownload.h"
#import "../YTMShared.h"
#import "../Localization/SCILocalize.h"

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface ELMNodeController : NSObject
@property (nonatomic, copy, readonly) NSString *key;
@end

@interface UIView (SCIYTMAncestor)
- (id)_viewControllerForAncestor;
@end

@interface ELMTouchCommandPropertiesHandler : NSObject
@end

// MARK: - Reading the app's own model, without running its code on faith

///
/// `-valueForKey:` is not a safe probe -- it runs the app's own getter, and this project crashed
/// Instagram once by trusting `@catch` to make that harmless. Every hop below asks the runtime
/// whether the key is real before touching it, and answers nil when it is not.
///
static id SCIYTMValue(id object, NSString *key) {
    if (!object || !key.length) return nil;

    SEL getter = NSSelectorFromString(key);
    if ([object respondsToSelector:getter]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, getter);
    }

    NSString *ivar = [@"_" stringByAppendingString:key];
    if (class_getInstanceVariable([object class], ivar.UTF8String) == NULL) return nil;

    @try {
        return [object valueForKey:key];
    } @catch (__unused id error) {
        return nil;
    }
}

static NSString *SCIYTMString(id object, NSString *key) {
    id value = SCIYTMValue(object, key);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

// MARK: - The manifest

///
/// The audio rendition, taken from the master playlist.
///
/// YouTube's audio groups are itag numbers: 234 is the higher bitrate, 233 the lower. They are
/// tried in that order and then **any** `TYPE=AUDIO` line is accepted, because a group id is a
/// name and this project has been burned four times by treating a name as a guarantee. A manifest
/// that offers audio under a third number still downloads.
///
static NSString *SCIYTMAudioURI(NSString *manifest) {
    if (!manifest.length) return nil;

    NSArray<NSString *> *lines =
        [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSArray<NSString *> *preferred = @[@"TYPE=AUDIO,GROUP-ID=\"234\"",
                                       @"TYPE=AUDIO,GROUP-ID=\"233\"",
                                       @"TYPE=AUDIO"];

    for (NSString *needle in preferred) {
        for (NSString *line in lines) {
            if (![line containsString:needle]) continue;

            NSRange start = [line rangeOfString:@"https://"];
            if (start.location == NSNotFound) continue;

            // The URI runs to the end of the line, or to the closing quote when the attribute is
            // quoted -- both shapes appear, and cutting at a fixed filename would refuse one.
            NSUInteger from = start.location;
            NSRange quote = [line rangeOfString:@"\"" options:0
                                          range:NSMakeRange(from, line.length - from)];
            NSUInteger to = (quote.location != NSNotFound) ? quote.location : line.length;

            NSString *uri = [[line substringWithRange:NSMakeRange(from, to - from)]
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (uri.length) return uri;
        }
    }

    return nil;
}

/// Every segment in a media playlist, made absolute.
static NSArray<NSURL *> *SCIYTMSegments(NSString *playlist, NSURL *base) {
    NSMutableArray<NSURL *> *segments = [NSMutableArray array];

    for (NSString *raw in [playlist componentsSeparatedByCharactersInSet:
                            [NSCharacterSet newlineCharacterSet]]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
        if (!line.length || [line hasPrefix:@"#"]) continue;

        NSURL *url = [line hasPrefix:@"http"] ? [NSURL URLWithString:line]
                                              : [NSURL URLWithString:line relativeToURL:base];
        if (url) [segments addObject:url.absoluteURL];
    }

    return segments;
}

// MARK: - Packed audio

///
/// An ID3v2 tag's length, or zero when there is not one here.
///
/// **YouTube's audio segments are packed ADTS behind an ID3 tag -- one tag per segment.** Joining
/// the segments and handing the result to AVFoundation gives a file with twenty-odd tags buried in
/// it, which is what "the download had no audio track" turned out to be in the YouTube tweak. The
/// same five constraints are checked here as there: the three letters, a version that is not 0xFF,
/// and four syncsafe length bytes -- together, chance does not meet them.
///
static NSUInteger SCIYTMID3Length(const uint8_t *bytes, NSUInteger at, NSUInteger length) {
    if (at + 10 > length) return 0;
    if (bytes[at] != 'I' || bytes[at + 1] != 'D' || bytes[at + 2] != '3') return 0;
    if (bytes[at + 3] == 0xFF || bytes[at + 4] == 0xFF) return 0;

    for (int i = 6; i < 10; i++) {
        if (bytes[at + i] & 0x80) return 0;
    }

    NSUInteger size = ((NSUInteger)bytes[at + 6] << 21) | ((NSUInteger)bytes[at + 7] << 14)
                    | ((NSUInteger)bytes[at + 8] << 7)  |  (NSUInteger)bytes[at + 9];

    return (at + 10 + size <= length) ? 10 + size : 0;
}

/// One segment's audio frames, with its tag taken off the front.
static NSData *SCIYTMStripTag(NSData *segment) {
    if (!segment.length) return segment;

    const uint8_t *bytes = segment.bytes;
    NSUInteger skip = SCIYTMID3Length(bytes, 0, segment.length);

    return skip ? [segment subdataWithRange:NSMakeRange(skip, segment.length - skip)] : segment;
}

// MARK: - Saying what happened

static void SCIYTMTell(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *key = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { key = window; break; }
        }

        UIViewController *top = key.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        if (!top) return;

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:title
                                                message:message
                                         preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

/// A name a file system will take, from a title a person wrote.
static NSString *SCIYTMSafeName(NSString *name) {
    NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    NSString *cleaned = [[name componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@" "];

    cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return cleaned.length ? cleaned : @"track";
}

// MARK: - The download

///
/// Fetches the master playlist, then the audio playlist, then every segment, and remuxes the
/// result to `.m4a`.
///
/// **`AVAssetExportPresetPassthrough` is the whole reason FFmpeg is not here.** The segments are
/// already AAC; nothing is decoded and nothing is re-encoded, which is what `-c copy` meant in the
/// port this was measured against. What the export does is put those frames in an MPEG-4 container
/// so the Files app, the Music app and anything else can read them.
///
static void SCIYTMDownloadTrack(NSURL *manifestURL, NSString *title, NSString *artist) {
    NSURLSession *session = [NSURLSession sharedSession];

    [[session dataTaskWithURL:manifestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *master = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSString *audioURI = SCIYTMAudioURI(master);

        if (!audioURI.length) {
            SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_no_audio"));
            return;
        }

        NSURL *audioURL = [NSURL URLWithString:audioURI];
        [[session dataTaskWithURL:audioURL completionHandler:^(NSData *listData, NSURLResponse *listResponse, NSError *listError) {
            NSString *playlist = listData.length ? [[NSString alloc] initWithData:listData encoding:NSUTF8StringEncoding] : nil;
            NSArray<NSURL *> *segments = SCIYTMSegments(playlist, audioURL);

            if (!segments.count) {
                SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_no_segments"));
                return;
            }

            //
            // Fetched one after another rather than all at once. A track is a few hundred small
            // segments; forty simultaneous connections is how a server decides to slow a client
            // down, and the ordering here has to be exact anyway.
            //
            NSMutableData *audio = [NSMutableData data];

            for (NSURL *segment in segments) {
                NSData *part = [NSData dataWithContentsOfURL:segment];
                if (!part.length) continue;
                [audio appendData:SCIYTMStripTag(part)];
            }

            if (!audio.length) {
                SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_empty"));
                return;
            }

            NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                stringByAppendingPathComponent:@"Albrhi"];
            [[NSFileManager defaultManager] createDirectoryAtPath:folder
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *name = artist.length ? [NSString stringWithFormat:@"%@ - %@", SCIYTMSafeName(artist), SCIYTMSafeName(title)]
                                           : SCIYTMSafeName(title);

            NSURL *raw = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.aac", name]]];
            NSURL *final = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.m4a", name]]];

            [[NSFileManager defaultManager] removeItemAtURL:raw error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:final error:nil];

            if (![audio writeToURL:raw atomically:YES]) {
                SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_not_written"));
                return;
            }

            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:raw options:nil];

            //
            // The length is waited for before anything is asked of it. A raw AAC file has no index,
            // so until AVFoundation has read it the track's `timeRange` is not a number -- and a
            // range built from that is what "the operation could not be completed" was in the
            // YouTube tweak, with nothing wrong in the media at all.
            //
            [asset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^{
                AVAssetExportSession *export =
                    [[AVAssetExportSession alloc] initWithAsset:asset
                                                     presetName:AVAssetExportPresetPassthrough];
                export.outputURL = final;
                export.outputFileType = AVFileTypeAppleM4A;

                [export exportAsynchronouslyWithCompletionHandler:^{
                    [[NSFileManager defaultManager] removeItemAtURL:raw error:nil];

                    if (export.status == AVAssetExportSessionStatusCompleted) {
                        SCIYTMTell(SCILocalized(@"download_saved"),
                            [NSString stringWithFormat:SCILocalized(@"download_saved_at"), name]);
                    } else {
                        SCIYTMTell(SCILocalized(@"download_failed"),
                            export.error.localizedDescription ?: SCILocalized(@"download_remux_failed"));
                    }
                }];
            }];
        }] resume];
    }] resume];
}

// MARK: - The app's own button

%group SCIYTMDownloadGroup

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    //
    // **The app's own download badge, intercepted before its Premium gate.**
    //
    // Both ivars are confirmed before they are read: `-valueForKey:` on a name a build does not
    // have runs the app's own code on the way to failing, and this project has a crash on record
    // for exactly that. A build without them takes `%orig` and nothing is lost.
    //
    if (!YTMU(@"YTMUltimateIsEnabled") ||
        class_getInstanceVariable([self class], "_controller") == NULL ||
        class_getInstanceVariable([self class], "_tapRecognizer") == NULL) {
        %orig;
        return;
    }

    ELMNodeController *node = [self valueForKey:@"_controller"];
    UIGestureRecognizer *recogniser = [self valueForKey:@"_tapRecognizer"];

    // One badge among many taps: the download one on the now-playing screen and nothing else.
    if (![node.key isEqualToString:@"music_download_badge_1"] ||
        ![[recogniser.view _viewControllerForAncestor] isKindOfClass:NSClassFromString(@"YTMNowPlayingViewController")]) {
        %orig;
        return;
    }

    id playingVC = [recogniser.view _viewControllerForAncestor];
    id playerVC = SCIYTMValue(playingVC, @"playerViewController") ?: SCIYTMValue(playingVC, @"playerVC");

    id playerResponse = SCIYTMValue(playerVC, @"playerResponse")
                     ?: SCIYTMValue(playerVC, @"contentPlayerResponse");
    id playerData = SCIYTMValue(playerResponse, @"playerData");
    id streaming = SCIYTMValue(playerData, @"streamingData");
    id details = SCIYTMValue(playerData, @"videoDetails");

    NSString *manifest = SCIYTMString(streaming, @"hlsManifestURL");
    if (!manifest.length) {
        // Nothing to download from: let the app do whatever it was going to do, rather than
        // swallowing a tap and leaving the button dead.
        %orig;
        return;
    }

    SCIYTMTell(SCILocalized(@"download_started"), SCILocalized(@"download_started_note"));

    SCIYTMDownloadTrack([NSURL URLWithString:manifest],
                        SCIYTMString(details, @"title") ?: @"track",
                        SCIYTMString(details, @"author"));
}

%end

%end

void SCIYTMInstallDownload(void) {
    Class handler = NSClassFromString(@"ELMTouchCommandPropertiesHandler");
    if (!handler) return;

    %init(SCIYTMDownloadGroup);
}
