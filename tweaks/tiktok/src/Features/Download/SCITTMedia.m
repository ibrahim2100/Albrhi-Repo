#import "SCITTMedia.h"
#import "../../TikTokHeaders.h"
#import "../../SCILog.h"
#import <objc/message.h>
#import <objc/runtime.h>

@implementation SCITTMediaItem
@end


/// Private: a model whose resolution is still pending, retried on a timer. Not part
/// of the public interface -- SCITTAdBlock.x only ever calls +captureModel:, which
/// calls this itself when the first attempt finds nothing.
@interface SCITTMedia ()
+ (void)watchModel:(AWEAwemeModel *)model;
+ (void)retryPending;
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
    // A list of URLs/strings (several candidate chains from the live property dump
    // end in one, e.g. -URLList) -- the first entry is the same choice this project's
    // other "several plausible sources" pickers make elsewhere.
    if ([value isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)value) {
            NSURL *url = SCITTURLFromValue(entry);
            if (url) return url;
        }
    }
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

/// `playURIString` answering a real object was the first chain to ever "resolve" --
/// and the download that followed it failed outright, which a plain HTTP or HTTPS
/// check would have caught before ever reaching the downloader. `NSURL URLWithString:`
/// happily builds a URL object out of an internal resource identifier that is not a
/// fetchable link at all -- this app almost certainly carries its own custom scheme or
/// a bare opaque ID for exactly this property, the same way `AVFoundation` names
/// carry `avkit_`/`_ttvideoengine_` prefixes on this same class. Treated as a failed
/// step rather than a success, so the resolver moves on to try the next chain instead
/// of handing the downloader something it can never fetch.
static BOOL SCITTURLLooksDownloadable(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
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
        // The second batch (downloadinfoModel, urlHolder, playURIString, playItem,
        // URLList) is read from AWEAwemeModel's own live property list -- a runtime
        // dump of this exact class on this exact device, not a string dump of a
        // binary. `-video` itself is on that list too and is included above already,
        // even though every capture so far has answered it nil; `+watchModel:` covers
        // the possibility that it is simply not populated yet at the moment a model is
        // first built, which construction-time capture alone cannot.
        // playURIString and URLList are tried last, not first: playURIString has
        // already been shown to resolve to *something* that is not an http(s) link
        // (a download attempted against it failed outright), and URLList's own
        // element type is not confirmed at all. The chains most likely to end at a
        // real AWEURLModel -- and therefore at bestURLtoDownload, the one doubly-
        // confirmed step in this whole file -- are tried first.
        NSArray<NSArray<NSString *> *> *chains = @[
            // Confirmed on a real device, one hop at a time, from the previous
            // report's own failures rather than guessed: -video answers a real
            // AWEVideoModel (it used to answer nil; +watchModel:'s retry is why it no
            // longer does), and AWEVideoModel -playURL answers a real AWEURLModel --
            // "chain ended at AWEURLModel, not a URL or string" said so outright, one
            // hop short of AWEURLModel's own doubly-confirmed -bestURLtoDownload.
            @[@"video", @"playURL", @"bestURLtoDownload"],
            @[@"videoModel", @"playAddr", @"bestURLtoDownload"],
            @[@"video", @"playAddr", @"bestURLtoDownload"],
            @[@"video", @"bestURLtoDownload"],
            @[@"downloadinfoModel", @"bestURLtoDownload"],
            @[@"downloadinfoModel", @"playAddr", @"bestURLtoDownload"],
            @[@"urlHolder", @"bestURLtoDownload"],
            @[@"playItem", @"bestURLtoDownload"],
            @[@"video", @"playURL"],
            @[@"video", @"url"],
            @[@"playURL"],
            @[@"videoModel", @"playURL"],
            @[@"urlHolder", @"url"],
            @[@"playURIString"],
            @[@"URLList"],
        ];

        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(model, chain, &failure);
            if (url && !SCITTURLLooksDownloadable(url)) {
                failure = [NSString stringWithFormat:
                    @"resolved to a non-http(s) link (%@) — treated as not downloadable",
                    url.scheme ?: @"no scheme"];
                url = nil;
            }
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

static void SCITTAddResolved(NSURL *url) {
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
}

+ (void)captureModel:(AWEAwemeModel *)model {
    if (!model) return;

    @try {
        NSURL *url = [self resolveURLForModel:model];
        if (url) {
            SCITTAddResolved(url);
            return;
        }

        // Nothing resolved yet -- possibly because none of the tried names are right,
        // possibly because the right one simply has not been populated on this model
        // this early. `+watchModel:` cannot tell those apart either, but retrying
        // costs nothing a first attempt has not already spent, and is the only way to
        // find out which one it is without guessing a third time.
        [self watchModel:model];
    } @catch (NSException *exception) {
        // A capture is a convenience; TikTok's own feed is not. Anything thrown here
        // costs this one row, never the app.
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"media capture: %@", exception.reason);
    }
}

///
/// A model whose first resolution attempt found nothing, watched weakly in case the
/// answer was simply not populated yet at construction time -- `-video` itself
/// existing on the live class but answering nil on every attempt so far is exactly
/// the shape that would produce. Weak, so nothing here extends how long a feed cell's
/// own model stays alive; a model that TikTok discards while still pending is simply
/// dropped from the next retry pass rather than kept alive for it.
///

static NSHashTable<AWEAwemeModel *> *sciPending = nil;
static NSMapTable<AWEAwemeModel *, NSNumber *> *sciRetryCounts = nil;
static NSTimer *sciRetryTimer = nil;
static NSUInteger const kSCIMaxRetries = 10;

+ (void)watchModel:(AWEAwemeModel *)model {
    if (!model) return;

    if (!sciPending) {
        sciPending = [NSHashTable weakObjectsHashTable];
        sciRetryCounts = [NSMapTable weakToStrongObjectsMapTable];
    }
    [sciPending addObject:model];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (sciRetryTimer) return;
        sciRetryTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                          repeats:YES
                                                            block:^(NSTimer *timer) {
            [SCITTMedia retryPending];
        }];
    });
}

+ (void)retryPending {
    if (!sciPending.count) return;

    for (AWEAwemeModel *model in [sciPending allObjects]) {
        NSUInteger tries = [sciRetryCounts objectForKey:model].unsignedIntegerValue;

        NSURL *url = [self resolveURLForModel:model];
        if (url) {
            SCITTAddResolved(url);
            [sciPending removeObject:model];
            [sciRetryCounts removeObjectForKey:model];
            continue;
        }

        tries++;
        if (tries >= kSCIMaxRetries) {
            // Given up on this one -- almost certainly a photo post or something else
            // with no video at all, not a resolution this project got wrong.
            [sciPending removeObject:model];
            [sciRetryCounts removeObjectForKey:model];
        } else {
            [sciRetryCounts setObject:@(tries) forKey:model];
        }
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
