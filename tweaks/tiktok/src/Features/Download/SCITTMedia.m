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

static void SCITTAddResolvedList(NSArray<NSURL *> *urls);

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
///
/// The highest-bitrate variant TikTok is offering, or nil.
///
/// **This is the HD question, and a chain of named accessors cannot answer it.** Every other
/// step in this file walks a path and takes the first thing it finds; `bitrateModels` is a
/// *list of alternatives* and the right one is chosen by comparing them, not by position.
/// Taking `.firstObject` here -- which is what the generic walker would do -- is how you get
/// whichever gear TikTok happened to list first, and that is the SD copy as often as not.
///
/// Each entry carries `-bitRate`, `-gearName`, `-qualityType` and its own `-playAddr`;
/// all four are confirmed present in TikTok 46.4.0's own binary. The address is a URL model
/// like every other, so the same `originURLList` / `urlList` reading applies to it.
///
/// Tried ahead of `downloadNoWatermarkURL`, which is what 0.11.0 settled on. That one is
/// correct about the *watermark* and says nothing about the size, and the report will show
/// which of the two won by the byte count alone.
static NSURL *SCITTBestBitrateURL(id videoModel, NSString **outVia) {
    SEL models = NSSelectorFromString(@"bitrateModels");
    if (![videoModel respondsToSelector:models]) return nil;

    id list = ((id (*)(id, SEL))objc_msgSend)(videoModel, models);
    if (![list isKindOfClass:[NSArray class]] || ![(NSArray *)list count]) return nil;

    id best = nil;
    long long bestRate = -1;

    for (id entry in (NSArray *)list) {
        SEL rate = NSSelectorFromString(@"bitRate");
        if (![entry respondsToSelector:rate]) continue;

        long long value = ((long long (*)(id, SEL))objc_msgSend)(entry, rate);
        if (value > bestRate) { bestRate = value; best = entry; }
    }

    if (!best) return nil;

    SEL addr = NSSelectorFromString(@"playAddr");
    if (![best respondsToSelector:addr]) return nil;

    id urlModel = ((id (*)(id, SEL))objc_msgSend)(best, addr);
    if (!urlModel) return nil;

    for (NSString *name in @[@"originURLList", @"urlList", @"URLList"]) {
        SEL selector = NSSelectorFromString(name);
        if (![urlModel respondsToSelector:selector]) continue;

        NSURL *url = SCITTURLFromValue(((id (*)(id, SEL))objc_msgSend)(urlModel, selector));
        if (!url) continue;

        if (outVia) {
            *outVia = [NSString stringWithFormat:@"bitrateModels[%lld bps].playAddr.%@",
                       bestRate, name];
        }
        return url;
    }

    return nil;
}

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
        // `-playURIString` and `-URLList` are **not** absent -- a live property dump from a
        // device lists both. They were dropped for resolving the wrong thing, which is a
        // different fact and worth stating correctly:
        // `URLList` resolved 288 times of 706 and the file it produced was 972 KB of
        // `audio/mp4` with no video track at all. It is the *sound's* URL list. Every
        // one of those "successes" was the music, which is worse than resolving
        // nothing. `-playURIString` was already rejected for answering a non-http(s)
        // link. `-h264URL` and `-downloadURL` were invented here and are gone too:
        // neither tweak sends them and neither binary carries them as strings.
        NSArray<NSArray<NSString *> *> *chains = @[
            // What actually exists in TikTok 46.4.0, read from the app's own binary.
            //
            // Every selector below was confirmed by dumping __objc_methname out of
            // MusicallyCore.framework -- 785 MB and 1,032,816 selectors, which is where
            // TikTok's classes live; its main executable is 91 KB and holds none of them,
            // the same way X's do not live in X's binary.
            //
            // **That dump also deleted three assumptions.** `bestURLtoDownload` is not in
            // this build at all, and it was the first choice of nearly every chain here --
            // so most of this list has been dead for as long as it has existed.
            // `bitratePlayURL`, `bestURLtoDownloadFormat` and `downloadHDVideo:` are absent
            // too; they came from NA9's binary, which was built against an older TikTok, and
            // reading a working tweak's selectors is not the same as confirming they are in
            // *your* build. That is the same trap the X tweak's dead immersive class was.
            //
            // The real quality ladder, in order:
            //
            //   `bitrateModels`  a list of variants, each with -bitRate, -gearName,
            //                    -qualityType and its own -playAddr. This is where HD is.
            //   `downloadAddr`   the *download* address, which is not `playAddr`: TikTok
            //                    serves playback at a bitrate chosen for smooth streaming.
            //                    "It saves SD" was this distinction all along.
            //   `playAddrH264`   an explicit codec-named address, ahead of the generic one.
            //
            // Each ends in a URL model, whose confirmed accessors are `originURLList`,
            // `urlList` and `URLList` -- not `bestURLtoDownload`, which does not exist.
            // AWEVideoModel's real accessors, dumped from the device at last.
            //
            // `downloadAddr` -- guessed at twice, from NA9's binary and from a global
            // selector dump -- **is not on this class**. A framework-wide selector list says
            // a name exists somewhere in 785 MB; it never says on what. The device printed
            // the class's own list and settled it in one line.
            //
            // What is there, in the order that matters:
            //
            //   downloadNoWatermarkURL   download quality, no watermark
            //   downloadURL              download quality
            //   h264DownloadURL          codec-named download
            //   bitrateModels            the HD ladder (also HDR/SDR variants)
            //   playURL                  the *streaming* URL -- what we had been using
            //   playLowBitURL            named for exactly what it is
            //
            // And `audioBitrateModels` sits right beside them, which is the shape of the
            // "972317 bytes of audio/mp4" this has been saving: the model carries separate
            // audio lists, and a URL picked without regard to which list it came from can
            // easily be the sound.
            @[@"video", @"downloadNoWatermarkURL", @"originURLList"],
            @[@"video", @"downloadNoWatermarkURL", @"urlList"],
            @[@"video", @"downloadNoWatermarkURL", @"URLList"],

            @[@"video", @"downloadURL", @"originURLList"],
            @[@"video", @"downloadURL", @"urlList"],
            @[@"video", @"downloadURL", @"URLList"],

            @[@"video", @"playURL", @"originURLList"],
            @[@"video", @"playURL", @"urlList"],
            @[@"video", @"h264DownloadURL"],
            @[@"video", @"h264DownloadURL", @"originURLList"],
            @[@"video", @"playURLList", @"originURLList"],
            @[@"video", @"playURLList", @"urlList"],
            @[@"video", @"originURLList"],
            // downloadInfoModel, with a capital I.
            //
            // These two read `downloadinfoModel` for as long as they have existed, and a
            // live property dump from a device settles it: the accessor is
            // `downloadInfoModel`. Selectors are case-sensitive, so both lines were dead --
            // -respondsToSelector: answered NO every time and the chain moved on without
            // ever asking the one object on the model whose entire purpose is download
            // information.
            @[@"downloadInfoModel", @"originURLList"],
        ];

        sciResolveAttempts++;

        // **Every chain is run, not just up to the first that answers.** One chain
        // resolving is not the same as it resolving the video: `originURLList` answered
        // reliably for several releases and every file it produced was `audio/mp4` with
        // no video track. Collecting all of them gives the downloader something to fall
        // back to, and the file itself gets to pick the winner.
        NSMutableArray<NSURL *> *found = [NSMutableArray array];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];

        // The best gear first, chosen by comparing bitrates rather than by taking the first
        // entry -- see SCITTBestBitrateURL. Collected into the same list as everything else,
        // at the front, so the downloader still gets to reject it if the file turns out not
        // to be a video; being the highest bitrate on offer is not a promise about content.
        SEL videoSel = NSSelectorFromString(@"video");
        id videoModel = [model respondsToSelector:videoSel]
            ? ((id (*)(id, SEL))objc_msgSend)(model, videoSel) : nil;

        if (videoModel) {
            NSString *via = nil;
            NSURL *best = SCITTBestBitrateURL(videoModel, &via);
            if (best && SCITTURLLooksDownloadable(best)) {
                [found addObject:best];
                sciWinningChain = via;
            }
        }

        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(model, chain, &failure);
            if (url && !SCITTURLLooksDownloadable(url)) {
                failure = [NSString stringWithFormat:@"non-http(s) (%@)",
                    url.scheme ?: @"no scheme"];
                url = nil;
            }
            if (url) {
                if (![found containsObject:url]) [found addObject:url];
                if (!sciWinningChain) {
                    sciWinningChain = [chain componentsJoinedByString:@"."];
                    sciWinningURLShape = SCITTURLShape(url);
                }
                continue;
            }
            [failures addObject:[NSString stringWithFormat:@"%@: %@",
                [chain componentsJoinedByString:@"."], failure ?: @"?"]];
        }

        if (found.count) {
            sciResolveSuccesses++;
            sciLastAttemptState = [NSString stringWithFormat:@"%lu candidate link(s)",
                (unsigned long)found.count];
            SCITTAddResolvedList(found);
            return found.firstObject;
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

static void SCITTAddResolvedList(NSArray<NSURL *> *urls) {
    if (!urls.count) return;
    if (!sciRecent) sciRecent = [NSMutableArray array];

    NSURL *primary = urls.firstObject;

    // Same video seen twice -- a recycled cell rebound, a scroll back up -- moves
    // to the front rather than duplicating.
    for (SCITTMediaItem *existing in [sciRecent copy]) {
        if ([existing.url isEqual:primary]) [sciRecent removeObject:existing];
    }

    SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
    item.url = primary;
    item.candidates = urls;
    item.seen = [NSDate date];
    [sciRecent insertObject:item atIndex:0];

    while (sciRecent.count > kSCIMediaCap) [sciRecent removeLastObject];
}

static void SCITTAddResolved(NSURL *url) {
    if (url) SCITTAddResolvedList(@[url]);
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
            // The same confirmed ladder as the aweme path above, for a video model reached
            // directly. downloadAddr before playAddr before playURL: download address, then
            // codec-named playback address, then the generic one.
            // Same confirmed ladder, for a video model reached directly.
            @[@"downloadNoWatermarkURL", @"originURLList"],
            @[@"downloadNoWatermarkURL", @"urlList"],
            @[@"downloadURL", @"originURLList"],
            @[@"downloadURL", @"urlList"],

            @[@"playURL", @"originURLList"],
            @[@"playURL", @"originURL"],
            @[@"playURL", @"originUrl"],
            @[@"playURL", @"urlList"],

            // VibeTok's own path, and the name suggests exactly what this feature
            // wants: the H.264 download link rather than a streaming address. Tried
            // both as a direct answer and as a container.
            @[@"h264DownloadURL"],
            @[@"h264DownloadURL", @"originURLList"],
            @[@"h264DownloadURL", @"urlList"],

            @[@"playURLList", @"originURLList"],
            @[@"playURLList", @"urlList"],
            @[@"playURLList"],

        ];

        // Every chain, same as the aweme path -- see the note there for why one
        // answering is not the same as one answering with the video.
        NSMutableArray<NSURL *> *found = [NSMutableArray array];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];

        for (NSArray<NSString *> *chain in chains) {
            NSString *failure = nil;
            NSURL *url = SCITTResolveChain(videoModel, chain, &failure);
            if (url && !SCITTURLLooksDownloadable(url)) {
                failure = [NSString stringWithFormat:@"non-http(s) (%@)", url.scheme ?: @"no scheme"];
                url = nil;
            }
            if (url) {
                if (![found containsObject:url]) [found addObject:url];
                if (!sciWinningChain) {
                    sciWinningChain = [NSString stringWithFormat:@"AWEVideoModel.%@",
                        [chain componentsJoinedByString:@"."]];
                    sciWinningURLShape = SCITTURLShape(url);
                }
                continue;
            }
            [failures addObject:[NSString stringWithFormat:@"%@: %@",
                [chain componentsJoinedByString:@"."], failure ?: @"?"]];
        }

        if (found.count) {
            sciResolveSuccesses++;
            sciLastAttemptState = [NSString stringWithFormat:
                @"AWEVideoModel — %lu candidate link(s)", (unsigned long)found.count];
            SCITTAddResolvedList(found);
            return;
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
/// Does `name` pass the filter -- **and an empty filter passes everything.**
///
/// The loop this replaces iterated the keyword list and added a name only from inside it, so
/// an empty list meant the body never ran and every class came back with nothing. Asking for
/// "no filter" produced "no results", which is the opposite of what it reads as, and the call
/// that wanted an unfiltered dump would have failed silently.
static BOOL SCITTNameMatches(NSString *name, NSArray<NSString *> *keywords) {
    if (!keywords.count) return YES;

    NSString *lower = name.lowercaseString;
    for (NSString *keyword in keywords) {
        if ([lower containsString:keyword.lowercaseString]) return YES;
    }
    return NO;
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
            if (SCITTNameMatches(name, keywords)) [names addObject:name];
        }
        if (props) free(props);

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(walk, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"]) continue; // getters only, no arguments
            if (SCITTNameMatches(name, keywords)) [names addObject:name];
        }
        if (methods) free(methods);

        walk = class_getSuperclass(walk);
    }

    if (!names.count) {
        return keywords.count
            ? [NSString stringWithFormat:@"%@: nothing matches %@",
                className, [keywords componentsJoinedByString:@"/"]]
            : [NSString stringWithFormat:@"%@: no accessors at all", className];
    }
    return [[names array] componentsJoinedByString:@", "];
}

@end
