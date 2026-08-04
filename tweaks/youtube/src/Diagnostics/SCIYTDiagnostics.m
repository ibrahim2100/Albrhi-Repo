#import "SCIYTDiagnostics.h"
#import "../Features/Dislikes/SCIYTDislikes.h"
#import "../YouTubeHeaders.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"
#import "../Features/Download/SCIYTDownload.h"
#import <objc/runtime.h>

///
/// The classes worth reporting on, and why each one is here.
///
/// A name alone is not enough: a report saying "YTSettingsSectionItem: found" tells
/// nobody anything unless it also says what depends on it. So each row carries the
/// question it answers.
///
static NSArray<NSDictionary *> *SCIAuditTable(void) {
    return @[
        @{@"class": @"YTSettingsSectionItem",         @"why": @"builds our settings rows"},
        @{@"class": @"YTSettingsViewController",      @"why": @"shows our settings section"},
        @{@"class": @"YTSettingsSectionItemManager",  @"why": @"answers for our category"},

        // These two are what actually put the section on screen. The one below them
        // looked like it did, and 0.1.0 shipped relying on it: it exists, it accepts
        // the category, and the screen never reads it.
        @{@"class": @"YTAppSettingsGroupPresentationData",
          @"why": @"the group list the screen is really built from"},
        @{@"class": @"YTSettingsGroupData",
          @"why": @"holds the categories — announcing one here crashed 0.1.1"},
        @{@"class": @"YTAppSettingsPresentationData",
          @"why": @"legacy category order; present but not consulted on 21.30.5"},

        @{@"class": @"YTPlayerOverlayWrapper",        @"why": @"hands us the player response"},
        @{@"class": @"MLVideo",                       @"why": @"carries the streams in use"},
        @{@"class": @"YTIPlayerResponse",            @"why": @"the response itself"},
        @{@"class": @"YTIStreamingData",             @"why": @"the stream list inside it"},

        // The two paths a download could take. Which of these is real decides
        // whether downloading is a week of work or a month, so the report says
        // plainly which one is present rather than leaving it to be assumed.
        @{@"class": @"YTOfflineVideoStreamsDownloadController",
          @"why": @"YouTube's own downloader — the path worth riding"},
        @{@"class": @"MLOnesieUMPController",
          @"why": @"the piecewise stream protocol — the path that needs a client"},
        @{@"class": @"MLServerABROnesieDataLoader",
          @"why": @"server-driven bitrate: no plain file URLs"},
    ];
}

@implementation SCIYTDiagnostics

// Held strongly, and exactly one of each.
//
// Weak was the first attempt and it was wrong: the response is released as soon as
// playback moves on, so by the time anyone walks over to Settings the page had
// nothing left to show — which is the one thing it exists to do. One protobuf
// message and one stream list is a bounded, deliberate cost, and each new video
// replaces them rather than adding to them.
//
// The video object itself is not kept: what the report needs from it is its ID and
// its streams, and holding the whole player-layer object to reach two fields would
// pin far more than this page is worth.
static id sciLastResponse = nil;
static id sciLastStreamingData = nil;

/// The last few videos' stream objects, by video id. See -recordVideo: for why.
static NSMutableDictionary<NSString *, id> *sciStreamsByVideo = nil;
static NSMutableArray<NSString *> *sciStreamsOrder = nil;

/// Player responses filed by video id, from the object that owns the clip.
///
/// **The reasoning that put this here was wrong, and it is kept because it still helps.**
/// 0.29.1 concluded Shorts never produces an MLVideo, from two reports showing the same
/// stale streams id while the clip changed. It does produce one; it simply runs a clip
/// ahead, and the keyed stream store was failing for an unrelated reason -- it was asking
/// MLStreamingData for a field only the player response has, fixed in 0.30.1.
///
/// This remains a second source for a clip the stream store has not filed yet, which is a
/// real case on the first Short of a session.
static NSMutableDictionary<NSString *, id> *sciResponsesByVideo = nil;
static NSMutableArray<NSString *> *sciResponsesOrder = nil;
static NSString *sciLastVideoID = nil;
static NSString *sciLastVideoTitle = nil;

/// Titles by video id. See -recordVideo: for why the newest one is the wrong one in Shorts.
static NSMutableDictionary<NSString *, NSString *> *sciTitlesByVideo = nil;

// The settings groups, as text, captured the moment the screen asked for them.
// Text and not the objects: the report needs the numbers and the names, and holding
// YouTube's model objects to reach two fields each would pin far more than that.
static NSString *sciSettingsGroups = nil;

+ (void)recordSettingsGroups:(NSArray *)groups {
    if (!groups.count) return;

    NSMutableString *text = [NSMutableString string];
    for (id group in groups) {
        unsigned long long type = 0;
        NSString *title = nil;

        if ([group respondsToSelector:@selector(type)]) {
            type = ((YTSettingsGroupData *)group).type;
        }
        if ([group respondsToSelector:@selector(title)]) {
            title = ((YTSettingsGroupData *)group).title;
        }

        // -orderedCategories is deliberately *not* called here.
        //
        // This runs inside +orderedGroups, while that method is still returning, and
        // asking a group for its contents at that moment means reading an object whose
        // construction may not have finished. The category count was never worth that:
        // what the next attempt needs from this report is which groups exist and what
        // number each one carries.
        [text appendFormat:@"  type %llu — %@\n", type, title ?: @"?"];
    }

    sciSettingsGroups = [text copy];
}

// Kept so the report can say the panel failed and why. A caught exception that is
// recorded nowhere is worse than one that crashes: the app survives and the fault goes
// silent, which is the exact failure mode this page exists to prevent.
static NSString *sciPanelFailure = nil;

+ (void)recordPanelFailure:(NSString *)reason {
    if (!reason.length) return;
    sciPanelFailure = [reason copy];
    [self writeReportToFile];
}

// The latest SponsorBlock line, and only the latest: this is a status, not a log, and
// a page that grows without bound is one nobody reads to the end of.
//
// Not written to the file on every update. This is touched on each time change during
// playback, and writing the whole report to disk that often would cost far more than
// the line is worth -- it lands on the next capture, which is a video away at most.
static NSString *sciSponsorState = nil;

+ (void)recordSponsorState:(NSString *)state {
    if (!state.length) return;
    sciSponsorState = [state copy];
}

// Which bar the markers landed on. Set on every layout pass of that bar, so it is
// assigned far more often than it changes -- a copy of a short string, and cheaper than
// the comparison that would avoid it.
static NSString *sciMarkerBar = nil;

+ (void)recordMarkerBar:(NSString *)className count:(NSInteger)count {
    if (!className.length) return;
    sciMarkerBar = [NSString stringWithFormat:SCILocalized(@"diag_markers_drawn"),
        className, (long)count];
}

/// What the counter nodes on screen said.
///
/// Bounded and de-duplicated: a list scrolls, the same two buttons are re-drawn many times,
/// and a report that says "Like" four hundred times answers nothing.
static NSMutableOrderedSet<NSString *> *sciCounterNodes = nil;

+ (void)recordCounterNode:(NSString *)text {
    if (!sciCounterNodes) sciCounterNodes = [NSMutableOrderedSet orderedSet];
    if (sciCounterNodes.count >= 8) return;

    [sciCounterNodes addObject:text.length ? text : @"(empty)"];
}

+ (NSArray<NSString *> *)counterNodes {
    return [sciCounterNodes array] ?: @[];
}

/// The last thing the Downloads tab did, in order, kept short.
///
/// Ordered rather than latest-only: attaching and drawing are two separate steps that fail
/// for different reasons, and "the icon did not appear" needs both answers at once -- was a
/// tab built, and did anything take the picture.
static NSMutableOrderedSet<NSString *> *sciTabStates = nil;

+ (void)recordTabState:(NSString *)state {
    if (!state.length) return;
    if (!sciTabStates) sciTabStates = [NSMutableOrderedSet orderedSet];
    if (sciTabStates.count >= 5) return;

    [sciTabStates addObject:state];
}

/// Running totals, not the last call: the feed is filled a page at a time, and the last
/// page alone says nothing about whether the ads were caught.
static NSUInteger sciFeedSeen = 0;
static NSUInteger sciFeedDropped = 0;

+ (void)recordFeedSections:(NSUInteger)seen dropped:(NSUInteger)dropped {
    sciFeedSeen += seen;
    sciFeedDropped += dropped;
}

/// Latest only, and appended to the feed line rather than given a section of its own --
/// it is a fact about that filter, and a reader looking at the counts is the reader who
/// needs to know the filter stood down.
static NSString *sciFeedBrake = nil;

+ (NSString *)feedState {
    if (!sciFeedSeen) return SCILocalized(@"diag_feed_none");

    NSString *counts = [NSString stringWithFormat:SCILocalized(@"diag_feed_counts"),
        (unsigned long)sciFeedSeen, (unsigned long)sciFeedDropped];

    // The brake belongs on the same line as the counts. Read on its own, "0 dropped" says
    // the filter recognised nothing -- which is a different problem from the filter standing
    // down because it recognised far too much, and they need different fixes.
    if (!sciFeedBrake.length) return counts;
    return [NSString stringWithFormat:@"%@\n  %@", counts, sciFeedBrake];
}

/// Latest only. This runs on every layout pass of the Shorts overlay, so a growing list
/// would be a log file inside a report.
static NSString *sciShortsButton = nil;

+ (void)recordShortsButton:(NSString *)state {
    if (state.length) sciShortsButton = [state copy];
}

/// The last save actually attempted, kept apart from the placement line above.
///
/// They shared one slot and placement won every time. Placement is written whenever an
/// overlay is built, which is on every clip you swipe to -- so tapping save wrote the one
/// line that mattered and the next swipe erased it. The report I asked for could never have
/// contained it.
///
/// This is 0.10.2 again: a record wiped by the activity it was measuring, in a different
/// file, after the lesson had been written down. A status and an event do not belong in one
/// variable, because the status is always the more recent of the two.
static NSString *sciShortsSave = nil;

+ (void)recordShortsSave:(NSString *)detail {
    if (detail.length) sciShortsSave = [detail copy];
    [self writeReportToFile];
}

+ (NSString *)shortsSaveState {
    return sciShortsSave ?: SCILocalized(@"diag_shorts_save_none");
}

/// Bounded and de-duplicated: the same file failing twice is one fact.
static NSMutableOrderedSet<NSString *> *sciPlaybackFailures = nil;

+ (void)recordPlaybackFailure:(NSString *)detail {
    if (!detail.length) return;
    if (!sciPlaybackFailures) sciPlaybackFailures = [NSMutableOrderedSet orderedSet];
    if (sciPlaybackFailures.count >= 6) return;

    [sciPlaybackFailures addObject:detail];
    [self writeReportToFile];
}

+ (void)recordFeedBrake:(NSString *)detail {
    if (!detail.length) return;
    sciFeedBrake = [detail copy];
    [self writeReportToFile];
}

+ (NSString *)playbackFailures {
    if (!sciPlaybackFailures.count) return SCILocalized(@"diag_playback_none");
    return [[sciPlaybackFailures array] componentsJoinedByString:@"\n  "];
}

/// Counted rather than listed: the interesting facts are whether this class exists on this
/// build at all and whether it is reached often, and a list of identical lines says neither.
static NSUInteger sciShortsAdsRefused = 0;
static NSString *sciShortsAdDetail = nil;

+ (void)recordShortsAd:(NSString *)detail {
    sciShortsAdsRefused += 1;
    if (detail.length) sciShortsAdDetail = [detail copy];
}

+ (NSString *)shortsAdState {
    if (!sciShortsAdsRefused) return SCILocalized(@"diag_shorts_ads_none");
    return [NSString stringWithFormat:SCILocalized(@"diag_shorts_ads_count"),
        (unsigned long)sciShortsAdsRefused, sciShortsAdDetail ?: @"?"];
}

+ (NSString *)shortsButtonState {
    return sciShortsButton ?: SCILocalized(@"diag_shorts_none");
}

+ (NSString *)tabState {
    if (!sciTabStates.count) return SCILocalized(@"diag_tab_none");
    return [[sciTabStates array] componentsJoinedByString:@"\n  "];
}

/// Which video the captured response is for.
///
/// This is the id that matters for downloading and it was the one nobody wrote down. The
/// HLS playlist the downloader uses comes out of sciLastResponse, and until now the only
/// ids kept were the MLVideo's and the announced one -- two different things, neither of
/// them this. So the guard added in 0.25.1 compared the video being asked for against an id
/// that had nothing to do with the playlist it was guarding, agreed with itself, and handed
/// over the wrong video's playlist. In Shorts all three ids differ routinely, which is why
/// it was wrong there every time and fine everywhere else.
static NSString *sciResponseVideoID = nil;

+ (void)recordPlayerResponse:(id)response {
    if (!response) return;
    sciLastResponse = response;
    sciResponseVideoID = nil;

    // Asked properly first, and only then read out of the text.
    //
    // The first version of this did the text alone, looking for `video_id: "`, and came back
    // empty every time -- the report said `playlist ?`. That made the guard downstream treat
    // every capture as somebody else's and refuse every download, which is worse than the
    // bug it was written for. Writing a guard on a value I had never once seen produced is
    // the whole of that mistake.
    @try {
        id details = [response valueForKey:@"videoDetails"];
        id identifier = details ? [details valueForKey:@"videoId"] : nil;

        if ([identifier isKindOfClass:[NSString class]] && [identifier length]) {
            sciResponseVideoID = [identifier copy];
        }
    } @catch (__unused NSException *exception) { }

    // Both spellings, because a GPBMessage prints proto field names and the accessor uses
    // the camel-cased one -- and which of the two a description carries is not something to
    // be confident about without looking.
    if (!sciResponseVideoID) {
        @try {
            NSString *text = [response description];

            for (NSString *key in @[@"video_id: \"", @"videoId: \""]) {
                NSRange found = [text rangeOfString:key];
                if (found.location == NSNotFound) continue;

                NSUInteger from = found.location + found.length;
                NSRange end = [text rangeOfString:@"\""
                                          options:0
                                            range:NSMakeRange(from, text.length - from)];
                if (end.location == NSNotFound) continue;

                sciResponseVideoID = [text substringWithRange:
                    NSMakeRange(from, end.location - from)];
                break;
            }
        } @catch (__unused NSException *exception) { }
    }

    SCILogV(@"captured player response %@ for %@", [response class], sciResponseVideoID);
}

+ (NSString *)responseVideoID { return sciResponseVideoID; }

+ (void)recordVideo:(id)video {
    if (!video) return;

    if ([video respondsToSelector:@selector(ID)]) {
        NSString *identifier = ((MLVideo *)video).ID;
        if ([identifier isKindOfClass:[NSString class]]) {
            sciLastVideoID = [identifier copy];
        }
    }

    if ([video respondsToSelector:@selector(streamingData)]) {
        sciLastStreamingData = [(MLVideo *)video streamingData];

        // Kept per video, not just the newest.
        //
        // "Which video is this capture for" turned out to be unanswerable from the capture
        // itself -- two readings of the response's own id came back empty -- and it is the
        // wrong question anyway. MLVideo carries an ID that has never failed to read, so the
        // streams can simply be filed under it and looked up by name later.
        //
        // That is what Shorts needs. The clip playing had its streams captured when it
        // became current; the next one's arrived afterwards and took the single slot. Both
        // are here, and asking for one by id gets the right one.
        if (sciLastVideoID.length && sciLastStreamingData) {
            if (!sciStreamsByVideo) sciStreamsByVideo = [NSMutableDictionary dictionary];

            // Bounded, and the oldest goes first. This holds YouTube's stream objects, so an
            // unbounded map would pin every video of the session.
            if (!sciStreamsOrder) sciStreamsOrder = [NSMutableArray array];

            // The oldest key, read before it is removed from the order.
            //
            // The first version took index 0 out of the order and then deleted the key of
            // whatever had become first -- so it evicted the second-oldest and left the
            // oldest in the dictionary with nothing tracking it, which grows without bound.
            // It also touched the order array before creating it.
            if (sciStreamsByVideo.count >= 6 && !sciStreamsByVideo[sciLastVideoID]) {
                NSString *oldest = sciStreamsOrder.firstObject;
                if (oldest) {
                    [sciStreamsByVideo removeObjectForKey:oldest];
                    [sciStreamsOrder removeObjectAtIndex:0];
                }
            }

            if (!sciStreamsByVideo[sciLastVideoID]) [sciStreamsOrder addObject:sciLastVideoID];
            sciStreamsByVideo[sciLastVideoID] = sciLastStreamingData;
        }
    }

    // The title, for naming the file a download produces. Best effort and never
    // required: an untitled save is a small annoyance, a crash here is not.
    @try {
        id details = [self value:@"videoDetails" from:video];
        NSString *title = [self value:@"title" from:details];
        NSString *author = [self value:@"author" from:details];

        if ([title isKindOfClass:[NSString class]] && title.length) {
            sciLastVideoTitle = [author isKindOfClass:[NSString class]] && author.length
                ? [NSString stringWithFormat:@"%@ - %@", author, title]
                : [title copy];

            // Filed by video id as well as kept as "the latest".
            //
            // The latest is the wrong one in Shorts, for the same reason the streams were:
            // MLVideo runs a clip ahead. A download was fetching the right video's playlist
            // -- proved from the address's own id -- and then naming the file after whatever
            // MLVideo was newest, so the saved clip arrived under the neighbouring clip's
            // title. Right bytes, wrong name, and from the outside those look identical.
            if (sciLastVideoID.length) {
                if (!sciTitlesByVideo) sciTitlesByVideo = [NSMutableDictionary dictionary];

                // Bounded like the others, and titles are small enough that six is generous.
                if (sciTitlesByVideo.count >= 12 && !sciTitlesByVideo[sciLastVideoID]) {
                    [sciTitlesByVideo removeAllObjects];
                }
                sciTitlesByVideo[sciLastVideoID] = sciLastVideoTitle;
            }
        }
    } @catch (__unused NSException *exception) {}

    SCILogV(@"captured video %@ (streams: %@)", sciLastVideoID,
            sciLastStreamingData ? @"yes" : @"no");

    // Refreshed on the file too, so the report is complete without the page having
    // to be reachable.
    [self writeReportToFile];
}

/// Only the rows the *features* depend on. The report lists more than this -- the
/// download paths, the settings model -- and none of those failing means a feature is
/// broken, so none of them may turn the identity badge amber.
+ (BOOL)featuresAttached {
    NSArray *required = @[
        @"YTAdsInnerTubeContextDecorator",
        @"YTAdShieldUtils",
        @"YTIPlayerResponse",
        @"YTLocalPlaybackController",
        @"YTInnerTubeCollectionViewController",
        @"YTIPlayabilityStatus",
        @"MLVideo",
    ];

    for (NSString *name in required) {
        if (objc_getClass([name UTF8String]) == NULL) {
            SCILogV(@"audit: %@ is missing", name);
            return NO;
        }
    }
    return YES;
}


+ (NSString *)titleForVideoID:(NSString *)videoID {
    return videoID.length ? sciTitlesByVideo[videoID] : nil;
}

+ (id)streamingDataForVideoID:(NSString *)videoID {
    return videoID.length ? sciStreamsByVideo[videoID] : nil;
}

+ (void)recordResponse:(id)response forVideo:(NSString *)videoID {
    if (!response || !videoID.length) return;

    if (!sciResponsesByVideo) sciResponsesByVideo = [NSMutableDictionary dictionary];
    if (!sciResponsesOrder) sciResponsesOrder = [NSMutableArray array];

    // Bounded and oldest-first, like the stream store: these are YouTube's own message
    // objects and an unbounded map would pin every clip swiped past in a session.
    if (sciResponsesByVideo.count >= 6 && !sciResponsesByVideo[videoID]) {
        NSString *oldest = sciResponsesOrder.firstObject;
        if (oldest) {
            [sciResponsesByVideo removeObjectForKey:oldest];
            [sciResponsesOrder removeObjectAtIndex:0];
        }
    }

    if (!sciResponsesByVideo[videoID]) [sciResponsesOrder addObject:videoID];
    sciResponsesByVideo[videoID] = response;
}

/// The last few things the Shorts model handed over, in order and de-duplicated.
///
/// Ordered rather than latest-only: whether this fires at all, and whether it fires before
/// the model knows its own id, are different faults that look identical from outside.
static NSMutableOrderedSet<NSString *> *sciShortsResponses = nil;

+ (void)recordShortsResponse:(NSString *)detail {
    if (!detail.length) return;
    if (!sciShortsResponses) sciShortsResponses = [NSMutableOrderedSet orderedSet];
    if (sciShortsResponses.count >= 5) return;

    [sciShortsResponses addObject:detail];
    [self writeReportToFile];
}

+ (NSString *)shortsResponseState {
    if (!sciShortsResponses.count) return SCILocalized(@"diag_shorts_resp_none");
    return [[sciShortsResponses array] componentsJoinedByString:@"\n  "];
}

+ (id)responseForVideoID:(NSString *)videoID {
    return videoID.length ? sciResponsesByVideo[videoID] : nil;
}
+ (id)lastPlayerResponse { return sciLastResponse; }
+ (NSString *)lastVideoID { return sciLastVideoID; }

/// The video the player actually started, as opposed to the last one it built an object
/// for. YouTube makes those for clips it is preloading too, so the two are not the same
/// question — and a download that asked the wrong one reported the video as private.
static NSString *sciActiveVideoID = nil;

/// What the format request did, client by client.
static NSMutableArray<NSString *> *sciStreamAttempts = nil;

+ (void)recordActiveVideoID:(NSString *)videoID {
    if (!videoID.length) return;

    sciActiveVideoID = [videoID copy];

    // The attempts are deliberately *not* cleared here.
    //
    // They used to be, so that the list always belonged to the video on screen. But
    // YouTube re-announces a video while one is being saved -- on a quality change, on a
    // resume -- and that wiped the record halfway through a download. The line naming
    // what the playlist turned out to be was gone by the time anyone opened the page,
    // which is exactly when it was wanted.
    //
    // The download clears them when it starts a round, which is the moment that actually
    // marks one attempt from the next.
}

+ (NSString *)activeVideoID { return sciActiveVideoID; }

/// Guarded, because this list is the one piece of the report written from more than one
/// thread, and it crashed the app the moment a second writer appeared.
///
/// Until 0.12.0 only the format request wrote here, always from its own network callback,
/// and one writer needs no lock. Then the transport converter began recording what a
/// stream declared -- from the conversion queue, while the report was being rendered on
/// the main thread. Mutating an array while it is enumerated is not a race that sometimes
/// loses a line; it throws, and the app went down the instant a download reached 100%.
///
/// The lock is on the class object so every path here shares one, and `attempts` hands
/// out a copy: a caller holding a snapshot cannot be enumerating the live array.
+ (void)clearStreamAttempts {
    @synchronized (self) {
        sciStreamAttempts = nil;
    }
}

+ (void)recordStreamAttempt:(NSString *)line {
    if (!line.length) return;

    @synchronized (self) {
        if (!sciStreamAttempts) sciStreamAttempts = [NSMutableArray array];

        // Bounded: two clients per video, and a run that somehow retried without end must
        // not turn the report into a log file. Raised from eight, because the download
        // path now contributes lines of its own and the earliest ones -- which say what
        // the playlist was -- must not be pushed out by the latest.
        if (sciStreamAttempts.count < 16) [sciStreamAttempts addObject:[line copy]];
    }
}

+ (NSArray<NSString *> *)attempts {
    @synchronized (self) {
        return [sciStreamAttempts copy];
    }
}
+ (NSString *)lastVideoTitle { return sciLastVideoTitle; }

+ (NSString *)appVersion {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length ? version : @"unknown";
}

/// A protobuf message prints its whole tree from -description, which is the entire
/// reason this page can report the truth without a single hard-coded field name.
/// Guarded all the same: an object that is not what we expect must produce a line in
/// the report, not a crash inside a diagnostic.
+ (NSString *)describeMessage:(id)message {
    if (!message) return nil;

    @try {
        NSString *text = [message description];
        return text.length ? text : nil;
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"<%@ could not be described: %@>",
                NSStringFromClass([message class]), exception.reason];
    }
}

+ (NSString *)report {
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_build")];
    [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_tweak_version"), SCIVersionString];
    [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_app_version"), [self appVersion]];
    [out appendFormat:@"  %@: %@\n\n", SCILocalized(@"diag_bundle"),
        [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_attached")];
    for (NSDictionary *row in SCIAuditTable()) {
        NSString *name = row[@"class"];
        BOOL present = objc_getClass([name UTF8String]) != NULL;
        [out appendFormat:@"  [%@] %@ — %@\n",
            present ? SCILocalized(@"diag_present") : SCILocalized(@"diag_absent"),
            name, row[@"why"]];
    }
    [out appendString:@"\n"];

    // First, because it is the answer to "I held two fingers and nothing happened".
    if (sciPanelFailure.length) {
        [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_panel_failed"), sciPanelFailure];
    }

    // Printed before the video section because when the settings section itself is
    // missing, this is the part that says why -- and in 0.1.0 it was missing.
    [out appendFormat:@"%@\n", SCILocalized(@"diag_groups")];
    [out appendString:sciSettingsGroups ?: [NSString stringWithFormat:@"  %@\n",
        SCILocalized(@"diag_groups_none")]];
    [out appendString:@"\n"];

    // Before the video section, because when someone says "it never skips anything"
    // this line is the answer: whether a video ID was read, whether segments came
    // back, and whether a skip was performed.
    [out appendFormat:@"%@\n  %@\n  %@\n\n", SCILocalized(@"diag_sponsor"),
        sciSponsorState ?: SCILocalized(@"diag_sponsor_none"),
        sciMarkerBar ?: SCILocalized(@"diag_markers_none")];

    // Which counter buttons were seen and what each said before anything was written into
    // it. The dislike node is picked out by its text, so when the number lands on the wrong
    // button -- or on none -- this is the line that says why.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_tab"), [self tabState]];

    // What the feed filter saw. 0.20.1 shipped a wider ad list and this line to judge it by,
    // and the line never got written -- so the release changed what is hidden and removed
    // the only way to tell what it hid.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_feed"), [self feedState]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts"), [self shortsButtonState]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts_save"), [self shortsSaveState]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts_resp"), [self shortsResponseState]];

    // All three at once, because the download bug was exactly these disagreeing and no
    // report ever showed more than two of them.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_ids"),
        [NSString stringWithFormat:SCILocalized(@"diag_ids_line"),
            sciLastVideoID ?: @"?", sciActiveVideoID ?: @"?", sciResponseVideoID ?: @"?"]];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_shorts_ads"), [self shortsAdState]];

    // Why a saved file would not open. This is the one thing looking at the tweak's own code
    // can never answer: the file is on disk and AVFoundation is the only witness to what is
    // wrong with it.
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_playback"), [self playbackFailures]];

    [out appendFormat:@"%@\n", SCILocalized(@"diag_counters")];

    // Said plainly when the feature is off, because the probe lives behind the same switch.
    // 0.18.0 printed "nothing asked yet" whether the hook had failed or the switch was
    // simply not on, which are opposite problems wearing one sentence.
    if (!SCIPrefEnabled(SCIPrefDislikes)) {
        [out appendFormat:@"  %@\n\n", SCILocalized(@"diag_counters_off")];
    } else {
        for (NSString *text in [self counterNodes]) {
            [out appendFormat:@"  \"%@\"\n", text];
        }
        if (![self counterNodes].count) {
            [out appendFormat:@"  %@\n", SCILocalized(@"diag_counters_none")];
        }
        [out appendFormat:@"  %@\n\n", [SCIYTDislikes lastState]];
    }

    [out appendFormat:@"%@\n", SCILocalized(@"diag_video")];

    if (!sciLastResponse && !sciLastStreamingData && !sciLastVideoID) {
        [out appendFormat:@"  %@\n", SCILocalized(@"diag_no_video")];
        return out;
    }

    if (sciLastVideoID.length) {
        [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_video_id"), sciLastVideoID];
    }

    // Printed beside it, and only when the two disagree. A silent mismatch here is what
    // sent the download asking YouTube about a video nobody was watching; the ids being
    // equal is the normal case and not worth a line.
    if (sciActiveVideoID.length && ![sciActiveVideoID isEqualToString:sciLastVideoID]) {
        [out appendFormat:@"  %@: %@\n", SCILocalized(@"diag_active_video"), sciActiveVideoID];
    }

    // A snapshot, never the live array: a download writing its next line while this
    // enumerates is the crash described above.
    NSArray<NSString *> *attempts = [self attempts];
    if (attempts.count) {
        [out appendFormat:@"\n%@\n", SCILocalized(@"diag_stream_attempts")];
        for (NSString *line in attempts) {
            [out appendFormat:@"  %@\n", line];
        }
    }

    // Enumerated rather than described: MLStreamingData is not a protobuf and its
    // -description is a class name and an address, which is what this section printed
    // for four releases.
    // What the downloader makes of the same streams, first: it answers "can this video
    // be saved" in one line, where the dump below answers "why not".
    [out appendFormat:@"\n%@\n  %@\n", SCILocalized(@"diag_downloadable"),
        [SCIYTDownload diagnosticsSummary]];

    NSString *streams = [self describeStreams:sciLastStreamingData];
    if (streams.length) {
        [out appendFormat:@"\n%@\n%@\n", SCILocalized(@"diag_streams"), streams];
    }

    NSString *full = [self describeMessage:sciLastResponse];
    if (full) {
        [out appendFormat:@"\n%@\n%@\n%@\n",
            SCILocalized(@"diag_response"), SCILocalized(@"diag_response_note"), full];
    }

    return out;
}

/// One value from an object, boxed, or nil. KVC rather than -performSelector: it
/// returns numbers as NSNumber without the caller having to know the return type,
/// which is the whole difficulty with an unfamiliar class.
+ (id)value:(NSString *)key from:(id)object {
    if (!object || !key.length) return nil;
    @try {
        if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

/// What MLStreamingData actually holds.
///
/// Its -description prints the class and an address and nothing else: it is not a
/// protobuf, so the trick that makes the player response readable does not work here,
/// and this section of the report has been saying "<MLStreamingData: 0x...>" since
/// 0.1.0 — the one measurement the download feature was waiting on.
///
/// The question is narrow and worth stating: does this build hand out plain file URLs
/// per format, or only the piecewise UMP/ABR stream? A URL in the list below means the
/// first; an empty list, or formats with no URL, means the second — and the difference
/// is a week of work against a month of it.
+ (NSString *)describeStreams:(id)streamingData {
    if (!streamingData) return nil;

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"  class: %@\n", NSStringFromClass([streamingData class])];

    // The names both this app and other tweaks use for the format lists. Asked in
    // order; every one that answers is reported, because which of them is populated
    // is exactly what is unknown.
    NSArray<NSString *> *containers = @[
        @"adaptiveStreams", @"adaptiveFormats", @"adaptiveFormatsArray",
        @"formats", @"formatsArray", @"allFormats", @"streams", @"videoStreams",
        @"audioStreams", @"progressiveStreams", @"hlsManifestURL", @"dashManifestURL",
    ];

    BOOL foundAny = NO;

    for (NSString *name in containers) {
        id value = [self value:name from:streamingData];
        if (!value) continue;

        foundAny = YES;

        if (![value isKindOfClass:[NSArray class]]) {
            [out appendFormat:@"  %@: %@\n", name, value];
            continue;
        }

        NSArray *list = value;
        [out appendFormat:@"  %@: %lu\n", name, (unsigned long)list.count];

        // Twelve is more than enough to see the shape of the ladder, and keeps the
        // page inside what a person will actually read.
        NSUInteger shown = MIN(list.count, (NSUInteger)12);
        for (NSUInteger i = 0; i < shown; i++) {
            id stream = list[i];

            id itag = [self value:@"itag" from:stream];
            NSString *mime = [self string:[self value:@"MIMEType" from:stream]
                                            ?: [self value:@"mimeType" from:stream]];
            NSString *quality = [self string:[self value:@"qualityLabel" from:stream]
                                               ?: [self value:@"quality" from:stream]];
            id width = [self value:@"width" from:stream];
            id height = [self value:@"height" from:stream];
            id fps = [self value:@"fps" from:stream] ?: [self value:@"frameRate" from:stream]
                     ?: [self value:@"videoFrameRate" from:stream];
            id bitrate = [self value:@"bitrate" from:stream] ?: [self value:@"averageBitrate" from:stream];

            // The decisive question, and the reason the whole page exists: is there a
            // fetchable link per format, or does playback go through the piecewise
            // protocol only? The first probe answered "?cpn=..." — a query fragment,
            // not a URL — so every name the stream might keep a real one under is asked
            // for, and the one that answered is named alongside it.
            // Every name that answers, not the first.
            //
            // This probe used to stop at the first non-empty one, and that single `break`
            // steered four releases down the wrong road. `URL` answers with "?cpn=…" — a
            // fragment — so the loop reported that and never tried `url`, `baseURL` or any
            // of the rest even once. "No links anywhere" was a conclusion drawn from a
            // list of one.
            //
            // The reference tweak whose download works reads `URL` and falls through to
            // the nested formatStream when it is not usable, which is exactly the step
            // this report was unable to show.
            NSMutableArray<NSString *> *links = [NSMutableArray array];

            for (NSString *key in @[@"URL", @"url", @"baseURL", @"streamURL", @"videoURL",
                                    @"assetURL", @"mediaURL", @"urlString", @"URLString",
                                    @"absoluteURL", @"downloadURL"]) {
                id candidate = [self value:key from:stream];
                if (!candidate) continue;

                NSString *text = [candidate isKindOfClass:[NSURL class]]
                    ? [(NSURL *)candidate absoluteString] : [self string:candidate];
                if (!text.length) continue;

                // A signed CDN link runs to a thousand characters of query string; the
                // opening is enough to tell a real one from a fragment.
                NSString *shown = text.length > 90
                    ? [[text substringToIndex:90] stringByAppendingString:@"…"] : text;
                [links addObject:[NSString stringWithFormat:@"%@ = %@", key, shown]];
            }

            NSString *link = links.count
                ? [links componentsJoinedByString:@"\n      "]
                : @"none";

            [out appendFormat:@"    [%@] %@ %@ %@x%@ %@fps %@bps\n      %@\n",
                itag ?: @"?", mime ?: @"?", quality ?: @"?",
                width ?: @"?", height ?: @"?", fps ?: @"?", bitrate ?: @"?", link];
        }

        if (list.count > shown) {
            [out appendFormat:@"    … and %lu more\n", (unsigned long)(list.count - shown)];
        }

        // What else a stream can be asked, taken from the runtime rather than guessed.
        // Printed once: if the fields above came back empty, this is the list that says
        // what to ask for instead.
        if (list.count) {
            [out appendFormat:@"  stream class: %@\n", NSStringFromClass([list.firstObject class])];
            [out appendFormat:@"  stream offers: %@\n", [self zeroArgumentSelectorsOn:list.firstObject]];

            // And what is nested inside it, which is the one place left to look.
            //
            // Every stream in a real report answered -URL with "?cpn=..." — a query
            // fragment and not a link — and four of the twelve were H.264, which iOS
            // plays. So the codec was never the obstacle; the missing link was. The
            // outer stream does not hold one, and this says whether the inner one does.
            //
            // If it does not either, the answer is settled: this build hands out no file
            // URLs at all and downloading has to go through YouTube's own downloader or
            // the piecewise protocol. That is a different project, and worth knowing
            // before starting it rather than after.
            id nested = [self value:@"formatStream" from:list.firstObject];
            if (nested) {
                [out appendFormat:@"  formatStream class: %@\n", NSStringFromClass([nested class])];
                [out appendFormat:@"  formatStream offers: %@\n",
                    [self zeroArgumentSelectorsOn:nested]];

                for (NSString *key in @[@"URL", @"url", @"baseURL", @"urlString"]) {
                    id candidate = [self value:key from:nested];
                    if (!candidate) continue;

                    NSString *text = [candidate isKindOfClass:[NSURL class]]
                        ? [(NSURL *)candidate absoluteString] : [self string:candidate];
                    if (!text.length) continue;

                    NSString *head = text.length > 120
                        ? [[text substringToIndex:120] stringByAppendingString:@"…"] : text;
                    [out appendFormat:@"  formatStream %@ = %@\n", key, head];
                }

                // A GPBMessage prints its whole tree, which for a format stream is every
                // field it carries — the fastest way to see a link that is under a name
                // nobody thought to ask for.
                NSString *tree = [self describeMessage:nested];
                if (tree.length && tree.length < 4000) {
                    [out appendFormat:@"  formatStream contents:\n%@\n", tree];
                }
            } else {
                [out appendString:@"  formatStream: nothing nested\n"];
            }
        }
    }

    if (!foundAny) {
        [out appendFormat:@"  no format list answered. offers: %@\n",
            [self zeroArgumentSelectorsOn:streamingData]];
    }

    return out;
}

/// The zero-argument selectors a class declares, as one line.
///
/// Asking the runtime instead of guessing is how the Instagram side found the DASH
/// manifest after three wrong guesses. Bounded, and only the class's own methods:
/// walking every superclass would print most of NSObject.
+ (NSString *)zeroArgumentSelectorsOn:(id)object {
    if (!object) return @"—";

    NSMutableArray<NSString *> *names = [NSMutableArray array];

    // Up the chain, not just the class itself. MLRemoteStream declares almost nothing
    // of its own -- the accessors are on its superclass -- so asking only the class
    // printed an empty list, which read as "this object offers nothing" when it in
    // fact offers everything the download feature needs to know about.
    //
    // Stopping before NSObject keeps -hash, -description and the rest out of it.
    Class cls = [object class];
    NSInteger levels = 0;

    while (cls && cls != [NSObject class] && levels++ < 6 && names.count < 90) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);

        for (unsigned int i = 0; i < count && names.count < 90; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@":"]) continue;      // takes arguments
            if ([name hasPrefix:@"."]) continue;           // .cxx_destruct
            if ([name hasPrefix:@"set"]) continue;         // setters answer nothing useful
            if ([names containsObject:name]) continue;     // overridden further down
            [names addObject:name];
        }

        free(methods);
        cls = class_getSuperclass(cls);
    }

    [names sortUsingSelector:@selector(compare:)];
    return names.count ? [names componentsJoinedByString:@", "] : @"—";
}

/// A value as text, whatever kind of object it turns out to be.
///
/// MIMEType came back as <HAMMIMEType: 0x…> — a wrapper, not a string — so the report
/// printed an address where a type should be. Anything that is not already a string is
/// asked for one before being given up on.
+ (NSString *)string:(id)value {
    if (!value) return nil;
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];

    for (NSString *key in @[@"stringValue", @"string", @"type", @"name", @"value"]) {
        id inner = [self value:key from:value];
        if ([inner isKindOfClass:[NSString class]] && [inner length]) return inner;
    }

    return [value description];
}

+ (NSString *)reportForDisplay {
    NSString *full = [self report];

    // 40 KB is far more than anyone reads on a phone and far less than TextKit
    // struggles with. The cut is announced rather than silent: a report that stops
    // without saying so is a report nobody can trust.
    const NSUInteger limit = 40000;
    if (full.length <= limit) return full;

    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
                      stringByAppendingPathComponent:@"AlbrhiYT-report.txt"];

    return [NSString stringWithFormat:@"%@\n\n%@",
            [full substringToIndex:limit],
            [NSString stringWithFormat:SCILocalized(@"diag_truncated"), path]];
}

+ (NSString *)writeReportToFile {
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *path = [directory stringByAppendingPathComponent:@"AlbrhiYT-report.txt"];

    NSError *error = nil;
    BOOL written = [[self report] writeToFile:path
                                   atomically:YES
                                     encoding:NSUTF8StringEncoding
                                        error:&error];

    // NSLog and not SCILogV: this line is the fallback for the case where the
    // settings section did not appear, so it cannot be behind a switch that only
    // that section can reach.
    if (written) {
        NSLog(@"[AlbrhiYT] report written to %@", path);
        return path;
    }

    NSLog(@"[AlbrhiYT] could not write the report to %@: %@", path, error.localizedDescription);
    return nil;
}

+ (UIViewController *)viewController {
    UIViewController *host = [[UIViewController alloc] init];
    host.title = SCILocalized(@"diag_title");
    host.view.backgroundColor = UIColor.systemBackgroundColor;

    // A text view rather than a table: the report is one long body of text whose
    // value is that it can be copied whole, and a table would invite splitting it
    // into rows that each lose the context of the one above.
    UITextView *text = [[UITextView alloc] init];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.editable = NO;
    text.backgroundColor = UIColor.clearColor;
    text.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    text.text = [SCIYTDiagnostics reportForDisplay];
    text.textContainerInset = UIEdgeInsetsMake(16, 14, 16, 14);
    [host.view addSubview:text];

    // The button reports back in its own title. A HUD would be another dependency
    // for one line of feedback, and the title is where the user is already looking.
    //
    // The button is held by a **strong** local, and this is the whole bug that made
    // this page crash the app for four releases.
    //
    // It used to be assigned straight into a __weak variable so the handler block
    // could reference it without a cycle. But a freshly built button assigned only to
    // a weak reference has nothing retaining it, and ARC is entitled to release it on
    // the spot -- so `copyButton` was nil before the next line ran. -addSubview: on nil
    // does nothing, and then `copyButton.topAnchor` was nil too, which is what
    // "a constraint cannot be made from an anchor to a constant" actually means: the
    // other side of the pair was missing. The report named it once the page was
    // wrapped, which is the argument for wrapping it.
    //
    // Strong for the layout, weak inside the handler, which is the pairing that was
    // wanted in the first place.
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyButton setTitle:SCILocalized(@"diag_copy") forState:UIControlStateNormal];

    __weak UIButton *weakCopy = copyButton;
    UIAction *action = [UIAction actionWithTitle:@""
                                          image:nil
                                     identifier:nil
                                        handler:^(__kindof UIAction *sender) {
        UIPasteboard.generalPasteboard.string = [SCIYTDiagnostics report];
        [weakCopy setTitle:SCILocalized(@"diag_copied") forState:UIControlStateNormal];
    }];
    [copyButton addAction:action forControlEvents:UIControlEventPrimaryActionTriggered];

    copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    copyButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    copyButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.14];
    copyButton.layer.cornerRadius = 14;
    copyButton.layer.cornerCurve = kCACornerCurveContinuous;
    [host.view addSubview:copyButton];

    UILayoutGuide *safe = host.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [text.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [text.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [text.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [text.bottomAnchor constraintEqualToAnchor:copyButton.topAnchor constant:-12],

        [copyButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [copyButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [copyButton.heightAnchor constraintEqualToConstant:48],
        [copyButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
    ]];

    return host;
}

@end
