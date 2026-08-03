#import "SCIYTPlayerStreams.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import <objc/runtime.h>
#import <objc/message.h>

/// A zero-argument getter's value, by selector or by key.
///
/// Both, because the two disagree on protobuf classes: a GPBMessage resolves its fields
/// at runtime, so -respondsToSelector: can answer NO for a field that KVC reads without
/// complaint. Trying only the first is how a real field looks absent.
static id SCIGet(id object, NSString *name) {
    if (!object || !name.length) return nil;

    // KVC first, and this order is the whole point.
    //
    // 0.8.2 sent the selector directly with objc_msgSend cast to return id, and that is
    // a crash rather than a wrong answer: -itag, -height and -bitrate return integers,
    // so the integer came back as a pointer and the next -integerValue sent a message to
    // it. The app went down on the first numeric field of the first format.
    //
    // valueForKey: reads the same getters and boxes whatever they return, primitives
    // included, which is exactly why the code this replaced used it. Sending the
    // selector was an optimisation nobody asked for, applied to a case where the return
    // type is not known in advance.
    @try {
        id value = [object valueForKey:name];
        if (value) return value;
    } @catch (__unused NSException *exception) {
        // Not KVC-readable. The selector may still exist and return an object.
    }

    // Only for object returns, and only once the signature says so. A GPBMessage
    // resolves fields dynamically, so this covers the case KVC declined while still
    // refusing to guess at a primitive.
    SEL selector = NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return nil;

    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || strcmp(signature.methodReturnType, @encode(id)) != 0) return nil;

    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSString *SCIGetString(id object, NSString *name) {
    id value = SCIGet(object, name);
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSURL class]]) return [(NSURL *)value absoluteString];
    return nil;
}


@implementation SCIYTPlayerStreams

static __weak id sciPlayer = nil;

/// Held strongly, and deliberately.
///
/// One object per video, replaced each time a new one starts, carrying a player response
/// and a nonce. Weak would mean the app deciding when the formats stop being readable,
/// which is the same class of problem as the idle controller this replaces — and the
/// diagnostics page has held the player response strongly since 0.1.0 for exactly that
/// reason.
static id sciPlaybackData = nil;

/// The nonce YouTube issued for this playback session, from the playback data.
///
/// This is what the fragment "?cpn=…" on every media-layer stream was pointing at all
/// along: the app keeps the nonce beside the streams rather than inside their URLs.
static NSString *sciCPN = nil;

+ (void)rememberPlayer:(id)player {
    sciPlayer = player;
}

/// Recorded during the walk, so asking for it later costs nothing.
static NSString *sciManifestURL = nil;

+ (void)rememberPlaybackData:(id)playbackData {
    sciPlaybackData = playbackData;

    // Cleared with the video. A stale manifest would download whatever was playing
    // before, which is the same class of fault as the stale video id in 0.7.1.
    sciManifestURL = nil;

    NSString *cpn = SCIGetString(playbackData, @"CPN");
    sciCPN = cpn.length ? cpn : nil;

    SCILogV(@"player streams: playback data %@, cpn %@",
            playbackData ? NSStringFromClass([playbackData class]) : @"nil",
            sciCPN ?: @"none");
}

+ (id)valueOf:(NSString *)name on:(id)object {
    return SCIGet(object, name);
}

+ (NSString *)stringOf:(NSString *)name on:(id)object {
    return SCIGetString(object, name);
}

///
/// What the walk found at each step, as one line for the report.
///
/// 0.8.0 recorded nothing when this path came up empty, so a report could not tell
/// "the player held formats but none had a link" from "the chain broke before it got
/// there" — and those are entirely different problems. Every step is named now, with
/// the class it actually returned, because a nil three levels down looks the same as a
/// nil at the top from the outside.
///
static NSMutableString *sciTrace = nil;

static void SCITrace(NSString *step, id value) {
    if (!sciTrace) sciTrace = [NSMutableString string];
    [sciTrace appendFormat:@"%@=%@ ", step,
        value ? NSStringFromClass([value class]) : @"nil"];
}

+ (NSString *)lastTrace {
    return sciTrace.length ? [sciTrace copy] : nil;
}

+ (NSString *)hlsManifestURLForVideo:(NSString *)videoID {
    // Straight to the capture filed under that id, with no walk and no guessing about which
    // of several sources is current. This is the whole point of filing them by name: the
    // question "is this capture for the video I want" becomes "give me the capture for the
    // video I want", which has an answer.
    id streamingData = [SCIYTDiagnostics streamingDataForVideoID:videoID];

    // Then the response filed for that clip, which is the only one Shorts ever produces.
    // 0.29.0 filed streams from MLVideo, and Shorts never builds one -- so that store is
    // always empty there, which looked exactly like having nothing filed at all.
    if (!streamingData) {
        id response = [SCIYTDiagnostics responseForVideoID:videoID];

        // Three depths, because what -didReceiveResponse: hands over is a *watch* response
        // for a reel item, not a player response. A watch response wraps one, so asking it
        // for streamingData directly gets nothing -- which is indistinguishable from nothing
        // having been filed, and is why 0.29.1 looked like it had not fired at all.
        //
        // Named rather than searched: these are the two field names a player response is
        // reached by, and a general walk over an unknown message tree is how a diagnostics
        // page turns into a crash.
        for (NSArray<NSString *> *path in @[@[@"streamingData"],
                                            @[@"playerResponse", @"streamingData"],
                                            @[@"reelPlayerResponse", @"streamingData"]]) {
            id node = response;
            for (NSString *step in path) {
                node = node ? SCIGet(node, step) : nil;
            }
            if (node) { streamingData = node; break; }
        }
    }

    if (!streamingData) return nil;

    return SCIGetString(streamingData, @"hlsManifestURL");
}

+ (NSString *)hlsManifestURL {
    // Walk first if nothing has yet, so holding the video works before the settings
    // screen has ever been opened.
    if (!sciManifestURL) [self formatObjects];
    return sciManifestURL;
}

/// Every player response the controller can offer.
///
/// Two places, because they are not always both populated: the controller's own, and the
/// one hanging off the video it has active.
+ (NSArray *)playerResponses {
    NSMutableArray *responses = [NSMutableArray array];

    // The playback data first, because it is the only one of these that was handed over
    // rather than gone looking for. Everything below it is a fallback for a build where
    // this hook does not fire.
    id fromPlayback = SCIGet(sciPlaybackData, @"playerResponse");
    SCITrace(@"playbackData", sciPlaybackData);
    if (fromPlayback) {
        [sciTrace appendString:@"playbackData.playerResponse✓ "];
        [responses addObject:fromPlayback];
    }

    id player = sciPlayer;
    if (!player) return responses;

    // Two names for the response and two for the video, because two working tweaks reach
    // it by different ones. YouMod takes -contentPlayerResponse off the controller;
    // DLEasy takes -playerResponse and -singleVideo, neither of which the controller
    // implements — so it must reach them through something else, and asking for both
    // here costs a message send that returns nil.
    //
    // Only -contentPlayerResponse and -activeVideo are confirmed on
    // YTPlayerViewController in 21.30.5. The others are leads, and the trace says which
    // one actually answered rather than leaving it to be assumed.
    for (NSString *name in @[@"contentPlayerResponse", @"playerResponse"]) {
        id response = SCIGet(player, name);
        if (response && ![responses containsObject:response]) {
            [sciTrace appendFormat:@"%@✓ ", name];
            [responses addObject:response];
        }
    }

    for (NSString *videoName in @[@"activeVideo", @"singleVideo", @"currentVideo"]) {
        id video = SCIGet(player, videoName);
        if (!video) continue;

        [sciTrace appendFormat:@"%@=%@ ", videoName, NSStringFromClass([video class])];

        for (NSString *name in @[@"contentPlayerResponse", @"playerResponse"]) {
            id response = SCIGet(video, name);
            if (response && ![responses containsObject:response]) {
                [sciTrace appendFormat:@"%@.%@✓ ", videoName, name];
                [responses addObject:response];
            }
        }
    }

    // And the one the overlay was handed, which the diagnostics page has been holding
    // since 0.1.0. It costs nothing to add, it is a YTIPlayerResponse directly rather
    // than a wrapper, and if the two above are empty on this build it may not be.
    id captured = [SCIYTDiagnostics lastPlayerResponse];
    if (captured && ![responses containsObject:captured]) {
        [responses addObject:captured];
    }

    return responses;
}

+ (NSArray *)formatObjects {
    sciTrace = [NSMutableString string];

    SCITrace(@"player", sciPlayer);

    NSMutableArray *formats = [NSMutableArray array];

    // Held rather than asked for twice: the walk is not free and the count is wanted at
    // the end.
    NSArray *responses = [self playerResponses];

    for (id response in responses) {
        // -contentPlayerResponse answers with YTPlayerResponse, the Objective-C wrapper;
        // the protobuf with the streams in it is its playerData. Falling back to the
        // response itself covers a build where the two are the same object.
        SCITrace(@"response", response);

        id playerData = SCIGet(response, @"playerData") ?: response;
        SCITrace(@"playerData", playerData);

        id streamingData = SCIGet(playerData, @"streamingData");
        SCITrace(@"streamingData", streamingData);
        if (!streamingData) continue;

        // The manifest-level links, which nothing has looked at yet.
        //
        // Every per-format link is absent on this build -- measured through four paths
        // now -- but a streaming data carries three more URLs of its own, one level up
        // from the formats. An HLS or DASH manifest is a list of ordinary http segment
        // links, and iOS has native support for fetching HLS; serverAbrStreamingURL is
        // the piecewise protocol's own endpoint and means the opposite.
        //
        // Which of the three is populated decides whether downloading is a week of work
        // or a different project, so the report says plainly which one answered.
        for (NSString *name in @[@"hlsManifestURL", @"dashManifestURL", @"serverAbrStreamingURL"]) {
            NSString *manifest = SCIGetString(streamingData, name);
            if (!manifest.length) continue;

            // Kept, because this is the one that downloading runs on. Not the ABR
            // endpoint: that is the piecewise protocol's own address and means the
            // opposite of a playlist.
            if ([name isEqualToString:@"hlsManifestURL"]) sciManifestURL = [manifest copy];

            NSString *head = manifest.length > 70
                ? [[manifest substringToIndex:70] stringByAppendingString:@"…"] : manifest;
            [sciTrace appendFormat:@"%@=%@ ", name, head];
        }

        // Both lists. adaptiveFormatsArray is where the quality ladder lives;
        // formatStreamsArray carries the muxed ones, which need no joining at all.
        for (NSString *key in @[@"adaptiveFormatsArray", @"formatStreamsArray"]) {
            id list = SCIGet(streamingData, key);
            if ([list isKindOfClass:[NSArray class]]) {
                [sciTrace appendFormat:@"%@=%lu ", key, (unsigned long)((NSArray *)list).count];
                [formats addObjectsFromArray:list];
            } else {
                SCITrace(key, list);
            }
        }
    }

    // And the media layer's own list, which was written off too early.
    //
    // The report said its streams carry no link, and that conclusion came from a probe
    // that asked for `URL`, got the fragment "?cpn=…", and stopped -- it never tried
    // `url`, `baseURL` or the nested formatStream even once. "No link under any name"
    // was drawn from a list of one name.
    //
    // The reference tweak whose downloading works reads both sources and appends
    // whichever answers. So does this now, and the caller reads every name rather than
    // the first.
    // Reached through the playback data's own video, not the controller's -activeVideo.
    //
    // That returned a YTSingleVideoController, which has no streaming data on it, so this
    // whole source was silently empty. YTPlaybackData answers -video with the media-layer
    // object directly, which is one more thing that argument was already carrying.
    id mlVideo = SCIGet(sciPlaybackData, @"video") ?: SCIGet(sciPlayer, @"activeVideo");
    SCITrace(@"mlVideo", mlVideo);

    id mlStreamingData = SCIGet(mlVideo, @"streamingData");
    SCITrace(@"mlStreamingData", mlStreamingData);

    // The media layer keeps a master playlist of its own, and it is a different field
    // from the response's. Worth a line either way: it is the one URL on this side that
    // was never asked for.
    // The HLS side of the media layer, in full.
    //
    // This is where every tweak whose downloading works ends up. YTLite reads exactly
    // this field and hands it to a bundled FFmpeg, which understands HLS natively --
    // nineteen of its twenty megabytes are that library. A master playlist is a list of
    // ordinary http segments, so it is a way through where per-format links are absent,
    // and per-format links are absent on this build through every path measured.
    //
    // hasHLSData first, because it is the cheap question: it says whether there is
    // anything here at all before three more are asked.
    id hasHLS = SCIGet(mlStreamingData, @"hasHLSData");
    if (hasHLS) [sciTrace appendFormat:@"hasHLSData=%@ ", hasHLS];

    NSString *master = SCIGetString(mlStreamingData, @"HLSMasterPlaylistURL");
    if (master.length) {
        // The media layer's copy, used only if the response had none. Both sides
        // answered with the same address on a real device, so either will do.
        if (!sciManifestURL) sciManifestURL = [master copy];
        NSString *head = master.length > 70
            ? [[master substringToIndex:70] stringByAppendingString:@"…"] : master;
        [sciTrace appendFormat:@"HLSMasterPlaylistURL=%@ ", head];
    }

    // And the per-variant list, which would be better still: a variant playlist skips
    // the master and names one quality directly.
    id hlsStreams = SCIGet(mlStreamingData, @"HLSStreams");
    if ([hlsStreams isKindOfClass:[NSArray class]]) {
        [sciTrace appendFormat:@"HLSStreams=%lu ", (unsigned long)((NSArray *)hlsStreams).count];
    } else if (hlsStreams) {
        SCITrace(@"HLSStreams", hlsStreams);
    }

    id mlStreams = SCIGet(mlStreamingData, @"adaptiveStreams");
    if ([mlStreams isKindOfClass:[NSArray class]]) {
        [sciTrace appendFormat:@"adaptiveStreams=%lu ", (unsigned long)((NSArray *)mlStreams).count];
        [formats addObjectsFromArray:mlStreams];
    }

    [sciTrace appendFormat:@"→ %lu formats", (unsigned long)formats.count];

    SCILogV(@"player streams: %lu formats from %lu responses",
            (unsigned long)formats.count, (unsigned long)responses.count);

    return formats;
}

+ (NSString *)preparedURLFrom:(NSString *)urlString {
    if (!urlString.length) return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (!components) return urlString;

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    BOOL hasRateBypass = NO;
    BOOL hasCPN = NO;

    for (NSURLQueryItem *item in components.queryItems) {
        // `n` throttles the transfer to roughly playback speed, which turns a download
        // into the length of the video.
        if ([item.name isEqualToString:@"n"]) continue;

        if ([item.name isEqualToString:@"ratebypass"]) hasRateBypass = YES;
        if ([item.name isEqualToString:@"cpn"]) hasCPN = YES;
        [items addObject:item];
    }

    if (!hasRateBypass) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"ratebypass" value:@"yes"]];
    }

    // A playback nonce identifies the session the fetch belongs to. YouTube generates
    // them itself, so one of its own is asked for before falling back to a random one --
    // a nonce it did not issue is still better than none, but not by as much.
    if (!hasCPN) {
        // The one YouTube issued for this session, taken from the playback data. It is
        // the right answer rather than a generated stand-in: the server knows this nonce,
        // and every media-layer stream in the diagnostics report was carrying it as a
        // bare fragment, which is what pointed here.
        NSString *cpn = sciCPN;

        // Only when the session did not supply one. Asking YouTube to mint a fresh nonce
        // and using it *instead* of the session's would be strictly worse -- the server
        // has never seen the new one, and it is the session's that the streams were
        // pointing at.
        if (!cpn.length) {
            Class utils = objc_getClass("YTDataUtils");
            if (utils && [utils respondsToSelector:@selector(generateClientSideNonce)]) {
                id generated = ((id (*)(Class, SEL))objc_msgSend)(utils, @selector(generateClientSideNonce));
                if ([generated isKindOfClass:[NSString class]] && ((NSString *)generated).length) {
                    cpn = generated;
                }
            }
        }

        if (!cpn) {
            // YouTube's own alphabet for these, and sixteen characters of it.
            static NSString *const alphabet =
                @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
            NSMutableString *random = [NSMutableString stringWithCapacity:16];
            for (NSUInteger i = 0; i < 16; i++) {
                [random appendFormat:@"%C", [alphabet characterAtIndex:arc4random_uniform((uint32_t)alphabet.length)]];
            }
            cpn = random;
        }

        [items addObject:[NSURLQueryItem queryItemWithName:@"cpn" value:cpn]];
    }

    components.queryItems = items;
    return components.string ?: urlString;
}

@end
