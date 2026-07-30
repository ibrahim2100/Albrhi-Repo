#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"

///
/// Keep playing with the screen off.
///
/// The permission is a server decision, not a client one: the player response carries a
/// playability status, and that status says whether this video may continue in the
/// background. Everything downstream -- the audio session, the now-playing controls,
/// the lock screen -- follows from that one answer.
///
/// So this is two hooks on two model classes, and nothing else. No audio session to
/// configure, no notification to observe, no view to find. The reference tweak that
/// does only this and ad hiding is 68 KB in total, and this is why.
///
/// YTIPlayabilityStatus answers for the response; MLVideo answers for the video the
/// media layer is actually playing. Both are asked, at different moments, and forcing
/// one while leaving the other means playback that stops depending on which path the
/// app happened to take.
///

%hook YTIPlayabilityStatus

- (BOOL)isPlayableInBackground {
    if (!SCIPrefEnabled(SCIPrefBackgroundPlay)) {
        return %orig;
    }
    return YES;
}

%end


%hook MLVideo

- (BOOL)playableInBackground {
    if (!SCIPrefEnabled(SCIPrefBackgroundPlay)) {
        return %orig;
    }
    return YES;
}

%end


%hook YTPlaybackData

- (BOOL)isPlayableInBackground {
    if (!SCIPrefEnabled(SCIPrefBackgroundPlay)) {
        return %orig;
    }
    return YES;
}

%end


///
/// The "please update" dialog, and the paid-promotion overlay.
///
/// Kept in this file rather than given one of their own: both are one selector each,
/// both are model-level answers, and a file per line of code makes a tree nobody reads.
///

%hook YTGlobalConfig

- (BOOL)shouldBlockUpgradeDialog {
    if (!SCIPrefEnabled(SCIPrefBlockUpdateNag)) {
        return %orig;
    }

    // Note the polarity: this asks whether to *block* the dialog, so YES is what
    // silences it. Returning NO here would have been the confident, wrong fix.
    return YES;
}

%end


%hook YTIPlayerResponse

- (id)paidContentOverlayElementRendererOptions {
    if (!SCIPrefEnabled(SCIPrefHidePaidPromo)) {
        return %orig;
    }

    // The "includes paid promotion" banner. Hidden only on request and off by default:
    // it is a disclosure, and quietly removing one for everybody is not this tweak's
    // decision to make.
    return nil;
}

%end
