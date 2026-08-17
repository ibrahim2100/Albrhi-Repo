#import "SCITTMedia.h"
#import "../../TikTokHeaders.h"
#import "../../SCILog.h"
#import <objc/message.h>
#import <objc/runtime.h>

@implementation SCITTMediaItem
@end


static NSMutableArray<SCITTMediaItem *> *sciRecent = nil;
static NSUInteger const kSCIMediaCap = 30;
static NSString *sciLastAttemptState = nil;

@implementation SCITTMedia

/// A value however TikTok's own accessor hands it back, turned into a URL without
/// assuming which shape it is -- `AWEURLModel -bestURLtoDownload` is confirmed to
/// exist and to be called by two reference tweaks; what type it actually returns on
/// this build is not, so both plausible shapes are read rather than one being trusted.
static NSURL *SCITTURLFromValue(id value) {
    if (!value) return nil;
    if ([value isKindOfClass:[NSURL class]]) return value;
    if ([value isKindOfClass:[NSString class]]) return [NSURL URLWithString:value];
    return nil;
}

/// Sends `name` to `obj` if it answers, guarded the same way every step in this file
/// already is. `outFailure` is set to why it did not, only when it did not.
static id SCITTTry(id obj, NSString *name, NSString **outFailure) {
    if (!obj) {
        if (outFailure) *outFailure = @"nil object";
        return nil;
    }
    SEL selector = NSSelectorFromString(name);
    if (![obj respondsToSelector:selector]) {
        if (outFailure) *outFailure = [NSString stringWithFormat:
            @"%@ has no -%@", NSStringFromClass([obj class]), name];
        return nil;
    }
    id result = ((id (*)(id, SEL))objc_msgSend)(obj, selector);
    if (!result && outFailure) {
        *outFailure = [NSString stringWithFormat:@"-%@ answered nil", name];
    }
    return result;
}

/// Walks `model` through one candidate chain of selector names, converting the last
/// step's answer to a URL. Returns nil and fills `outFailure` on the step that stopped
/// it -- never a guess past a step that did not answer.
static NSURL *SCITTResolveChain(id model, NSArray<NSString *> *chain, NSString **outFailure) {
    id current = model;
    for (NSString *step in chain) {
        NSString *failure = nil;
        current = SCITTTry(current, step, &failure);
        if (!current) {
            if (outFailure) *outFailure = failure;
            return nil;
        }
    }
    NSURL *url = SCITTURLFromValue(current);
    if (!url && outFailure) {
        *outFailure = [NSString stringWithFormat:@"chain ended at %@, not a URL or string",
            NSStringFromClass([current class])];
    }
    return url;
}

+ (NSURL *)resolveURLForModel:(AWEAwemeModel *)model {
    if (!model) return nil;

    @try {
        // Several candidate paths, tried in order -- not because all are equally
        // likely, but because a live device report is what actually tells this project
        // which name a given build uses, and guessing exactly one path is what put a
        // now-confirmed-wrong `-videoModel` here the first time. `bestURLtoDownload`
        // is the one doubly-confirmed step (a real string in the binary and NA9's own
        // hooked selector) and appears in every chain that plausibly reaches
        // `AWEURLModel`; `-video`, `-playURL` and `-url` are read from NA9's own
        // `_objc_msgSend$…` message-send stubs -- real selectors this binary actually
        // sends, not guessed names, though not confirmed to be sent specifically to an
        // aweme model the way `-isAds` and `AWEURLModel`'s own method are.
        NSArray<NSArray<NSString *> *> *chains = @[
            @[@"videoModel", @"playAddr", @"bestURLtoDownload"],
            @[@"video", @"playAddr", @"bestURLtoDownload"],
            @[@"video", @"bestURLtoDownload"],
            @[@"video", @"playURL"],
            @[@"video", @"url"],
            @[@"playURL"],
            @[@"videoModel", @"playURL"],
        ];

        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(model, chain, &failure);
            if (url) {
                sciLastAttemptState = [NSString stringWithFormat:
                    @"resolved via %@", [chain componentsJoinedByString:@"."]];
                return url;
            }
            [failures addObject:[NSString stringWithFormat:@"%@: %@",
                [chain componentsJoinedByString:@"."], failure ?: @"?"]];
        }

        sciLastAttemptState = [NSString stringWithFormat:@"every chain failed — %@",
            [failures componentsJoinedByString:@" | "]];
        return nil;
    } @catch (NSException *exception) {
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"media resolve: %@", exception.reason);
        return nil;
    }
}

+ (void)captureModel:(AWEAwemeModel *)model {
    if (!model) return;

    @try {
        NSURL *url = [self resolveURLForModel:model];
        if (!url) return;

        if (!sciRecent) sciRecent = [NSMutableArray array];

        // Same video seen twice -- a recycled cell rebound, a scroll back up -- moves
        // to the front rather than duplicating.
        for (SCITTMediaItem *existing in [sciRecent copy]) {
            if ([existing.url isEqual:url]) [sciRecent removeObject:existing];
        }

        SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
        item.url = url;
        item.seen = [NSDate date];
        [sciRecent insertObject:item atIndex:0];

        while (sciRecent.count > kSCIMediaCap) [sciRecent removeLastObject];
    } @catch (NSException *exception) {
        // A capture is a convenience; TikTok's own feed is not. Anything thrown here
        // costs this one row, never the app.
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"media capture: %@", exception.reason);
    }
}

+ (NSArray<SCITTMediaItem *> *)recent {
    return [sciRecent copy] ?: @[];
}

+ (void)forgetAll {
    [sciRecent removeAllObjects];
}

+ (NSString *)lastAttemptState {
    return sciLastAttemptState ?: @"nothing captured yet";
}

+ (NSString *)candidateAccessorsOnAwemeModel {
    Class cls = NSClassFromString(@"AWEAwemeModel");
    if (!cls) return @"AWEAwemeModel not in this build";

    NSArray<NSString *> *keywords =
        @[@"video", @"play", @"url", @"media", @"cover", @"download", @"aweme"];
    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];

    // The chain from a model to its video may sit on a superclass rather than on
    // AWEAwemeModel itself -- TikTok's own model hierarchy is not something this
    // project has a class dump of, so a few levels up are read too rather than
    // assuming the property lives on the exact class that was hooked.
    Class walk = cls;
    for (int depth = 0; walk && depth < 4; depth++) {
        unsigned int propCount = 0;
        objc_property_t *props = class_copyPropertyList(walk, &propCount);
        for (unsigned int i = 0; i < propCount; i++) {
            NSString *name = [NSString stringWithUTF8String:property_getName(props[i])];
            NSString *lower = name.lowercaseString;
            for (NSString *keyword in keywords) {
                if ([lower containsString:keyword]) { [names addObject:name]; break; }
            }
        }
        if (props) free(props);

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(walk, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"]) continue; // getters only, no arguments
            NSString *lower = name.lowercaseString;
            for (NSString *keyword in keywords) {
                if ([lower containsString:keyword]) { [names addObject:name]; break; }
            }
        }
        if (methods) free(methods);

        walk = class_getSuperclass(walk);
    }

    if (!names.count) return @"nothing on this class matches video/play/url/media";
    return [[names array] componentsJoinedByString:@", "];
}

@end
