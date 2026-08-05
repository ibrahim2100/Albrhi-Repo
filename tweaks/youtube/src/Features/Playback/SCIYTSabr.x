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


/// Declared so the setter can be called on a value the hook below already holds.
@interface MLOnesieRequestContext : NSObject
- (void)setBypassOnesie:(BOOL)bypassOnesie;
@end

%hook MLOnesieRequestContext

/// Writing the value, not just answering for it.
///
/// Forcing the getter was measured on 21.30.5 and changed nothing: the setting was on, the
/// gate was forced four times in one playback, and all twenty formats came back with the
/// same empty `?cpn=` URL they always had. That result is real, but it proves something
/// narrower than it looks — that *this getter's answer* does not decide the request. Code
/// inside the object reading its own instance variable never went through the hook at all.
///
/// So this writes the stored value through the class's own setter, right after it is built.
/// If the request is assembled from the ivar, this reaches it and the getter hook never
/// could. If nothing changes again, the two together rule out the client end of it and what
/// is left is the server, which no hook here can argue with.
///
/// The initialiser is named in full rather than caught by a shorter one, because it is the
/// only one this class has that builds a configured context, and its `visibility` and
/// `isPrefetch` arguments are an int and a BOOL among twelve objects — a signature that has
/// to be exact or the arguments arrive shifted.
- (id)initWithConfig:(id)config
                 CPN:(id)cpn
             videoID:(id)videoID
        QOEController:(id)qoeController
 viewportSizeProvider:(id)viewportSizeProvider
        latencyLogger:(id)latencyLogger
           visibility:(int)visibility
       stickySettings:(id)stickySettings
watchEndpointUstreamerConfig:(id)watchEndpointUstreamerConfig
           isPrefetch:(BOOL)isPrefetch
 reloadPlaybackParams:(id)reloadPlaybackParams
           audioTrack:(id)audioTrack
defaultActiveSourceVideoID:(id)defaultActiveSourceVideoID
        startTimeSecs:(id)startTimeSecs {
    id context = %orig;

    if (context && SCIPrefEnabled(SCIPrefBypassSABR)) {
        [context setBypassOnesie:YES];
        [SCIYTDiagnostics recordSabrGate:@"MLOnesieRequestContext.setBypassOnesie:"
                                original:NO
                                  forced:YES];
    }

    return context;
}

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
