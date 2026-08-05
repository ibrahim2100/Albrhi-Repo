#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// YouTube's own switches for its piecewise streaming — watched, and no longer touched.
///
/// SABR — server adaptive bitrate — is why every format in this build answers with an empty
/// URL. The client does not fetch files; it asks a server-side controller for byte ranges
/// over UMP, and the format list describes what that controller may send rather than a list
/// of things that can be downloaded. Nine releases went into working around exactly that:
/// the HLS playlist, the transport-stream demuxer, the parallel part fetcher and the joiner
/// all exist because there was no URL to ask for.
///
/// The binary carries two gates for the same protocol:
///
///     MLPlayerReloadContext   -disableSABR     B16@0:8
///     MLOnesieRequestContext  -bypassOnesie    B16@0:8   (and -setBypassOnesie:)
///
/// **Both were tried, all the way, and the answer is no.** Written up here rather than in a
/// commit message because the idea is attractive enough to have again:
///
///   - `disableSABR` is never consulted on a first load at all. It is a reload-path gate,
///     and no amount of answering it differently reaches the request that matters.
///
///   - `bypassOnesie` is consulted, three to four times per playback. Forcing the getter
///     changed nothing — every format still came back `?cpn=` with no URL. That result was
///     narrower than it looked, since code reading the instance variable directly never went
///     through the hook, so the stored value was then written through the class's own setter
///     until the getter answered YES on its own account. **Still nothing.** Twenty-two
///     formats, no URLs.
///
///   - And it cost something: with the bypass in force the HLS manifest stopped arriving,
///     which is the one thing the downloader actually uses.
///
/// So the client end is ruled out by measurement, not by argument: the request can be made,
/// and the server declines to answer it differently. The metadata proves the shape of it —
/// `content_length`, `init_range` and `index_range` all arrive complete, and the URL alone is
/// withheld. That is a server-side decision about which clients get plain files, and nothing
/// running inside this app can change it.
///
/// The counting stays because it costs nothing and a future build may behave differently;
/// the forcing and its setting are gone. A switch that provably does nothing is a switch
/// that lies, and shipping it turned off would only mean somebody finds it later.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///

%hook MLPlayerReloadContext

- (BOOL)disableSABR {
    BOOL original = %orig;

    [SCIYTDiagnostics recordSabrGate:@"MLPlayerReloadContext.disableSABR"
                            original:original
                              forced:NO];
    return original;
}

%end


%hook MLOnesieRequestContext

- (BOOL)bypassOnesie {
    BOOL original = %orig;

    [SCIYTDiagnostics recordSabrGate:@"MLOnesieRequestContext.bypassOnesie"
                            original:original
                              forced:NO];
    return original;
}

%end


%ctor {
    // Said once at load, because "the gate was never consulted" and "the class is not in
    // this build" look identical in a report that only counts calls.
    SCILogV(@"[SABR] MLPlayerReloadContext:%@ MLOnesieRequestContext:%@",
            NSClassFromString(@"MLPlayerReloadContext") ? @"present" : @"absent",
            NSClassFromString(@"MLOnesieRequestContext") ? @"present" : @"absent");

    [SCIYTDiagnostics recordSabrClasses:(NSClassFromString(@"MLPlayerReloadContext") != nil)
                                 onesie:(NSClassFromString(@"MLOnesieRequestContext") != nil)];
}
