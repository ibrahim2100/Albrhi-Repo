#import "../../YouTubeHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// The two switches YouTube keeps for its own piecewise streaming, and a way to watch them.
///
/// SABR — server adaptive bitrate — is why every format in this build answers with an empty
/// URL. The client does not fetch files; it asks a server-side controller for byte ranges
/// over UMP, and the format list is a description of what that controller may send rather
/// than a list of things that can be downloaded. Nine releases of this tweak went into
/// working around exactly that: the HLS playlist, the transport-stream demuxer, the parallel
/// part fetcher and the joiner all exist because there was no URL to ask for.
///
/// The binary carries two gates for the same protocol, and their signatures are the evidence
/// rather than their names:
///
///     MLPlayerReloadContext   -disableSABR     B16@0:8
///     MLOnesieRequestContext  -bypassOnesie    B16@0:8   (and -setBypassOnesie:)
///
/// **Whether the client asks does not decide what the server answers.** YouTube may take a
/// non-SABR request and reply with SABR-only streaming data regardless, and that is not
/// something this file can find out from here. So this is written to be a measurement first
/// and a change second: with the setting off — which is how it ships — every hook here does
/// nothing but count, and the diagnostics page says whether the gates are consulted at all.
/// If they never are, the idea is finished in one report and nothing that works was touched.
///
/// Only when the setting is on does anything get forced, and the existing streams section of
/// the report answers the rest: if per-format URLs appear there, the whole download path can
/// become one request instead of ninety.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///

%hook MLPlayerReloadContext

/// Consulted when playback is reloaded, not on the first load — so a report showing this
/// gate untouched after one video is not yet evidence of anything.
- (BOOL)disableSABR {
    BOOL original = %orig;

    if (!SCIPrefEnabled(SCIPrefBypassSABR)) {
        [SCIYTDiagnostics recordSabrGate:@"MLPlayerReloadContext.disableSABR"
                                original:original
                                  forced:NO];
        return original;
    }

    [SCIYTDiagnostics recordSabrGate:@"MLPlayerReloadContext.disableSABR"
                            original:original
                              forced:YES];
    return YES;
}

%end


%hook MLOnesieRequestContext

/// The request shape that carries a SABR response.
///
/// The getter rather than the setter, deliberately: a value stored before we are asked is
/// still read through here, and a setter hook would only catch the writes that happen to go
/// through it. What the object's own internals read directly is beyond reach either way.
- (BOOL)bypassOnesie {
    BOOL original = %orig;

    if (!SCIPrefEnabled(SCIPrefBypassSABR)) {
        [SCIYTDiagnostics recordSabrGate:@"MLOnesieRequestContext.bypassOnesie"
                                original:original
                                  forced:NO];
        return original;
    }

    [SCIYTDiagnostics recordSabrGate:@"MLOnesieRequestContext.bypassOnesie"
                            original:original
                              forced:YES];
    return YES;
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
