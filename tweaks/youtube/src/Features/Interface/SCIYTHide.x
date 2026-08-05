#import "../../YouTubeHeaders.h"
#import "../../Prefs.h"

///
/// Things on screen that can be answered away.
///
/// Every gate here is a `BOOL` getter YouTube asks itself before drawing something, found by
/// its type encoding rather than by its name — `B16@0:8`, a no-argument BOOL. Answering one
/// differently is not hiding a view after it exists; it is the app deciding not to build it,
/// which is why nothing in this file touches a frame, a superview or an alpha.
///
/// That distinction is the whole reason these were chosen over the obvious view-layer
/// approach. A hidden view still lays out, still reserves its space, and comes back the
/// moment the app reloads its own state. A gate answered NO is answered NO for the lifetime
/// of the screen.
///
/// **Every switch here ships off.** These remove parts of somebody else's app, and which
/// parts are worth removing is not a question this tweak gets to answer for everyone.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///


//
// The glow behind the player.
//
// Three gates rather than one because the container asks a different one depending on how it
// got there — allowed, available, eligible — and answering only the first leaves the effect
// arriving by the other two routes.
//
%hook YTWatchCinematicContainerController

- (BOOL)isCinematicLightingAllowed {
    if (SCIPrefEnabled(SCIPrefHideAmbient)) return NO;
    return %orig;
}

- (BOOL)isCinematicLightingAvailable {
    if (SCIPrefEnabled(SCIPrefHideAmbient)) return NO;
    return %orig;
}

- (BOOL)isCinematicLightingEligible {
    if (SCIPrefEnabled(SCIPrefHideAmbient)) return NO;
    return %orig;
}

%end


//
// The player overlay's own two questions.
//
// The endscreen is the grid of suggestions that covers the last seconds of a video; the
// infocard teasers are the small pop-outs a creator schedules mid-video.
//
%hook YTMainAppVideoPlayerOverlayViewController

- (BOOL)shouldShowAutonavEndscreen {
    if (SCIPrefEnabled(SCIPrefHideEndscreen)) return NO;
    return %orig;
}

- (BOOL)shouldShowInfocardTeasers {
    if (SCIPrefEnabled(SCIPrefHideInfoCards)) return NO;
    return %orig;
}

%end


// The controller that owns the endscreen, asked separately from the overlay above. Both, for
// the same reason the three cinematic gates are all hooked.
%hook YTAutonavEndscreenController

- (BOOL)shouldShowEndscreen {
    if (SCIPrefEnabled(SCIPrefHideEndscreen)) return NO;
    return %orig;
}

%end


//
// The buttons across the top of the app.
//
// This is an *event* — the object the navigation bar is handed when it is asked to update
// itself — and not the bar. So these answers are read on every update, including the ones
// that happen after a tab change, which is exactly where a view-layer approach loses.
//
%hook YTUpdateNavBarResponderEvent

- (BOOL)hideNotificationButton {
    if (SCIPrefEnabled(SCIPrefHideNotifyButton)) return YES;
    return %orig;
}

- (BOOL)hideCreationButton {
    if (SCIPrefEnabled(SCIPrefHideCreateButton)) return YES;
    return %orig;
}

- (BOOL)hideMDXButton {
    if (SCIPrefEnabled(SCIPrefHideCastButton)) return YES;
    return %orig;
}

- (BOOL)hideSearchButton {
    if (SCIPrefEnabled(SCIPrefHideSearchButton)) return YES;
    return %orig;
}

%end


// The promotional row inside the share sheet.
%hook YTShareMainView

- (BOOL)shouldShowPromo {
    if (SCIPrefEnabled(SCIPrefHideSharePromo)) return NO;
    return %orig;
}

%end
