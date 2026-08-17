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

///
/// Successes counted and the winning chain remembered separately from the last
/// attempt, and this distinction cost two releases of fixing the wrong thing.
///
/// `sciLastAttemptState` alone is overwritten by *every* attempt, and the overwhelming
/// majority of attempts are brand-new models a moment after construction whose video
/// data is not populated yet -- so the row read "every chain failed" while the feed
/// button, which only ever appears when a URL has actually been resolved, was visibly
/// appearing. The failing line was the last of two hundred attempts, not the verdict
/// on all of them. A count of successes and the name of the chain that produced them
/// cannot be drowned out that way.
///
static NSUInteger sciResolveSuccesses = 0;
static NSUInteger sciResolveAttempts = 0;
static NSString *sciWinningChain = nil;

/// **The one fact never recorded, and the reason this went round in circles.** A chain
/// name alone says which selectors answered, not *what* they answered with -- and the
/// saved file kept coming back byte-identical (972317 bytes of `audio/mp4`) release
/// after release, which only the URL itself could explain. A music CDN host and a video
/// CDN host are told apart at a glance; "resolved via video.playURL.originURLList" is
/// not. Truncated to host plus the last path component, so it identifies the *kind* of
/// link without putting a signed, account-scoped URL in a report meant to be pasted.
static NSString *sciWinningURLShape = nil;

static NSString *SCITTURLShape(NSURL *url) {
    if (!url) return @"nil";
    return [NSString stringWithFormat:@"%@/…/%@",
        url.host ?: @"?", url.lastPathComponent ?: @"?"];
}

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
        // The aweme model is now only a fallback -- `SCITTCapture.x` hooks
        // `AWEVideoModel` directly, because `-video` here is nil for nearly every
        // model at construction time. What is left are the same confirmed-sent
        // selectors `+captureVideoModel:` uses, reached one hop further out through
        // `-video` (sent by both reference tweaks) for the cases where it *is*
        // populated by the time a retry runs.
        //
        // `-playURIString` and `-URLList` are gone, and that is a measured removal:
        // `URLList` resolved 288 times of 706 and the file it produced was 972 KB of
        // `audio/mp4` with no video track at all. It is the *sound's* URL list. Every
        // one of those "successes" was the music, which is worse than resolving
        // nothing. `-playURIString` was already rejected for answering a non-http(s)
        // link. `-h264URL` and `-downloadURL` were invented here and are gone too:
        // neither tweak sends them and neither binary carries them as strings.
        NSArray<NSArray<NSString *> *> *chains = @[
            @[@"video", @"playURL", @"bestURLtoDownload"],
            @[@"video", @"playURL", @"originURLList"],
            @[@"video", @"playURL", @"urlList"],
            @[@"video", @"h264DownloadURL"],
            @[@"video", @"h264DownloadURL", @"originURLList"],
            @[@"video", @"playURLList", @"originURLList"],
            @[@"video", @"playURLList", @"urlList"],
            @[@"video", @"bestURLtoDownload"],
            @[@"video", @"originURLList"],
            @[@"downloadinfoModel", @"bestURLtoDownload"],
            @[@"downloadinfoModel", @"originURLList"],
            @[@"urlHolder", @"bestURLtoDownload"],
            @[@"playItem", @"bestURLtoDownload"],
        ];

        sciResolveAttempts++;

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
                sciResolveSuccesses++;
                sciWinningChain = [chain componentsJoinedByString:@"."];
                sciWinningURLShape = SCITTURLShape(url);
                sciLastAttemptState = [NSString stringWithFormat:
                    @"resolved via %@", sciWinningChain];
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

+ (void)captureVideoModel:(id)videoModel {
    if (!videoModel) return;

    @try {
        sciResolveAttempts++;

        // Only chains that end at AWEURLModel's own doubly-confirmed
        // -bestURLtoDownload, sent to the video model itself rather than to an aweme
        // model whose -video is nil at construction time. -playURL is confirmed on this
        // class by a device report ("chain ended at AWEURLModel"); -playAddr and
        // -bitratePlayAddr are tried after it because the reference tweaks name them
        // and one of them may be what a different build populates first.
        //
        // **Every selector below except the last two is a confirmed *sent* selector**,
        // taken from `_objc_msgSend$…` stub symbols in NA9's and VibeTok's own
        // binaries -- a stub the compiler emits only for a selector it actually saw
        // being sent, which is a far higher bar than a name appearing as a string.
        // The two tweaks turned out to use different names for the same job, and
        // reading only one of them is what kept this feature broken:
        //
        //   selector              NA9 sends   VibeTok sends
        //   playURL               yes         -
        //   h264DownloadURL       -           yes
        //   playURLList           -           yes
        //   bestURLtoDownload     yes         -
        //   originURL             yes         -
        //   originUrl             -           yes      (note the casing)
        //   originURLList         yes         yes      <- both, the strongest signal
        //   urlList               -           yes
        //
        // `originURLList` is the only one both tweaks send, so it is tried early on
        // every container. `-h264URL` and `-downloadURL`, which earlier versions of
        // this list guessed at, are sent by neither tweak and appear as strings in
        // neither binary -- they were invented here and are gone. `-playAddr` and
        // `-bitratePlayAddr` are strings only, never sent, so they stay last.
        //
        NSArray<NSArray<NSString *> *> *chains = @[
            @[@"playURL", @"bestURLtoDownload"],
            @[@"playURL", @"originURLList"],
            @[@"playURL", @"originURL"],
            @[@"playURL", @"originUrl"],
            @[@"playURL", @"urlList"],

            // VibeTok's own path, and the name suggests exactly what this feature
            // wants: the H.264 download link rather than a streaming address. Tried
            // both as a direct answer and as a container.
            @[@"h264DownloadURL"],
            @[@"h264DownloadURL", @"bestURLtoDownload"],
            @[@"h264DownloadURL", @"originURLList"],
            @[@"h264DownloadURL", @"urlList"],

            @[@"playURLList", @"originURLList"],
            @[@"playURLList", @"urlList"],
            @[@"playURLList", @"bestURLtoDownload"],
            @[@"playURLList"],

            @[@"playAddr", @"bestURLtoDownload"],
            @[@"bitratePlayAddr", @"bestURLtoDownload"],
        ];

        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(videoModel, chain, &failure);
            if (url && !SCITTURLLooksDownloadable(url)) {
                failure = [NSString stringWithFormat:@"non-http(s) (%@)", url.scheme ?: @"no scheme"];
                url = nil;
            }
            if (url) {
                sciResolveSuccesses++;
                sciWinningChain = [NSString stringWithFormat:@"AWEVideoModel.%@",
                    [chain componentsJoinedByString:@"."]];
                sciWinningURLShape = SCITTURLShape(url);
                sciLastAttemptState = [NSString stringWithFormat:@"resolved via %@", sciWinningChain];
                SCITTAddResolved(url);
                return;
            }
            [failures addObject:[NSString stringWithFormat:@"%@: %@",
                [chain componentsJoinedByString:@"."], failure ?: @"?"]];
        }

        sciLastAttemptState = [NSString stringWithFormat:@"AWEVideoModel — every chain failed: %@",
            [failures componentsJoinedByString:@" | "]];
    } @catch (NSException *exception) {
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"video model capture: %@", exception.reason);
    }
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
    if (!sciResolveAttempts) return @"nothing captured yet";

    // Successes first and prominently -- see the note beside sciResolveSuccesses for
    // why the last attempt's own text alone was actively misleading.
    NSMutableString *out = [NSMutableString stringWithFormat:@"%lu resolved of %lu tried",
        (unsigned long)sciResolveSuccesses, (unsigned long)sciResolveAttempts];

    if (sciWinningChain) {
        [out appendFormat:@"; via %@", sciWinningChain];
    }
    if (sciWinningURLShape) {
        [out appendFormat:@"; link %@", sciWinningURLShape];
    }
    [out appendFormat:@"; %lu kept", (unsigned long)sciRecent.count];

    // The last attempt's own detail is kept, but only after the counts, and only when
    // nothing has ever succeeded -- once one chain works, two hundred lines about
    // models that were merely asked too early say nothing worth the space.
    if (!sciResolveSuccesses && sciLastAttemptState) {
        [out appendFormat:@" — last: %@", sciLastAttemptState];
    }

    return out;
}

+ (NSString *)candidateAccessorsOnAwemeModel {
    return [self accessorsOnClassNamed:@"AWEAwemeModel"
                              matching:@[@"video", @"play", @"url", @"media",
                                         @"cover", @"download", @"aweme"]];
}

+ (NSString *)accessorsOnClassNamed:(NSString *)className
                            matching:(NSArray<NSString *> *)keywords {
    Class cls = NSClassFromString(className);
    if (!cls) return [NSString stringWithFormat:@"%@ not in this build", className];

    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];

    // The accessor may sit on a superclass rather than on the named class itself --
    // TikTok's own hierarchy is not something this project has a class dump of, so a
    // few levels up are read too rather than assuming it is declared exactly here.
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

    if (!names.count) {
        return [NSString stringWithFormat:@"%@: nothing matches %@",
            className, [keywords componentsJoinedByString:@"/"]];
    }
    return [[names array] componentsJoinedByString:@", "];
}

@end
