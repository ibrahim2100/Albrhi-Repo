#import "SCIYTPlayerStreams.h"
#import "../../SCILog.h"
#import <objc/runtime.h>
#import <objc/message.h>

/// A zero-argument getter's value, by selector or by key.
///
/// Both, because the two disagree on protobuf classes: a GPBMessage resolves its fields
/// at runtime, so -respondsToSelector: can answer NO for a field that KVC reads without
/// complaint. Trying only the first is how a real field looks absent.
static id SCIGet(id object, NSString *name) {
    if (!object || !name.length) return nil;

    SEL selector = NSSelectorFromString(name);
    if ([object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }

    @try {
        return [object valueForKey:name];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *SCIGetString(id object, NSString *name) {
    id value = SCIGet(object, name);
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSURL class]]) return [(NSURL *)value absoluteString];
    return nil;
}


@implementation SCIYTPlayerStreams

static __weak id sciPlayer = nil;

+ (void)rememberPlayer:(id)player {
    sciPlayer = player;
}

+ (id)valueOf:(NSString *)name on:(id)object {
    return SCIGet(object, name);
}

+ (NSString *)stringOf:(NSString *)name on:(id)object {
    return SCIGetString(object, name);
}

/// Every player response the controller can offer.
///
/// Two places, because they are not always both populated: the controller's own, and the
/// one hanging off the video it has active.
+ (NSArray *)playerResponses {
    id player = sciPlayer;
    if (!player) return @[];

    NSMutableArray *responses = [NSMutableArray array];

    id direct = SCIGet(player, @"contentPlayerResponse");
    if (direct) [responses addObject:direct];

    id activeVideo = SCIGet(player, @"activeVideo");
    id fromVideo = SCIGet(activeVideo, @"contentPlayerResponse");
    if (fromVideo && ![responses containsObject:fromVideo]) {
        [responses addObject:fromVideo];
    }

    return responses;
}

+ (NSArray *)formatObjects {
    NSMutableArray *formats = [NSMutableArray array];

    for (id response in [self playerResponses]) {
        // -contentPlayerResponse answers with YTPlayerResponse, the Objective-C wrapper;
        // the protobuf with the streams in it is its playerData. Falling back to the
        // response itself covers a build where the two are the same object.
        id playerData = SCIGet(response, @"playerData") ?: response;
        id streamingData = SCIGet(playerData, @"streamingData");
        if (!streamingData) continue;

        // Both lists. adaptiveFormatsArray is where the quality ladder lives;
        // formatStreamsArray carries the muxed ones, which need no joining at all.
        for (NSString *key in @[@"adaptiveFormatsArray", @"formatStreamsArray"]) {
            id list = SCIGet(streamingData, key);
            if ([list isKindOfClass:[NSArray class]]) {
                [formats addObjectsFromArray:list];
            }
        }
    }

    SCILogV(@"player streams: %lu formats from %lu responses",
            (unsigned long)formats.count, (unsigned long)[self playerResponses].count);

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
        NSString *cpn = nil;

        Class utils = objc_getClass("YTDataUtils");
        if (utils && [utils respondsToSelector:@selector(generateClientSideNonce)]) {
            id generated = ((id (*)(Class, SEL))objc_msgSend)(utils, @selector(generateClientSideNonce));
            if ([generated isKindOfClass:[NSString class]] && ((NSString *)generated).length) {
                cpn = generated;
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
