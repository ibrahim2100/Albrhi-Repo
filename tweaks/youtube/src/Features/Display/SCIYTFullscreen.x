#import "../../YouTubeHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// Which way round the video goes when it fills the screen.
///
/// YouTube decides this from how the phone happens to be held, and gets it wrong constantly:
/// lying on your side, the video arrives upside down relative to you and the only fix is to
/// sit up. The app has one question it asks before the transition —
///
///     YTWatchViewController  -allowedFullScreenOrientations    Q16@0:8
///
/// returning a `UIInterfaceOrientationMask` — and answering it with a single orientation is
/// the whole feature. Nothing here rotates anything or touches a transform; iOS rotates to
/// the only orientation left standing.
///
/// **The button and the swipe are separate settings**, because they are separate habits: the
/// button is deliberate and the swipe is often accidental, and a person who wants the button
/// to always land left may well want the swipe left alone.
///
/// The pair of triggers moved between builds, and this is the part worth writing down: the
/// tweak this idea came from holds them on `YTPlayerViewController`, where they no longer
/// exist in 21.30.5. Both are alive on `YTPlayerOverlayManager` instead — verified by type
/// encoding, not by assuming the rename went the way it looks like it went.
///
/// Idea and hook points from fosterbarnes/YTweaks (GPLv3); the code is our own.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///

/// What a direction setting means. Stored as these numbers, so reordering the picker can
/// never quietly change what somebody chose.
typedef NS_ENUM(NSInteger, SCIFullscreenDirection) {
    SCIFullscreenDirectionOff      = 0,
    SCIFullscreenDirectionLeft     = 1,
    SCIFullscreenDirectionRight    = 2,
    SCIFullscreenDirectionPortrait = 3,
};

/// Which tap or swipe is being served, if any.
typedef NS_ENUM(NSInteger, SCIFullscreenSource) {
    SCIFullscreenSourceNone   = 0,
    SCIFullscreenSourceButton = 1,
    SCIFullscreenSourceSwipe  = 2,
};

static SCIFullscreenSource sciArmedSource = SCIFullscreenSourceNone;

/// How long an arming survives.
///
/// The question is asked somewhere inside the transition, and whether that is on the same
/// runloop turn as the tap is not something the binary says. So the arming is bounded by
/// time rather than cleared after the first answer: asked twice during one transition, both
/// answers are the forced one, and if it is never asked the arming still cannot outlive the
/// tap that set it.
///
/// A second and a half — long enough for any transition, short enough that a later rotation
/// the user performs by hand is answered by YouTube and not by us.
static const NSTimeInterval kSCIArmedWindow = 1.5;

static UIInterfaceOrientationMask SCIMaskFor(SCIFullscreenDirection direction) {
    switch (direction) {
        // UIKit's naming is the opposite of what it sounds like and right for once:
        // LandscapeLeft is the phone turned so its top goes left, which is what a person
        // means by "rotate left".
        case SCIFullscreenDirectionLeft:     return UIInterfaceOrientationMaskLandscapeLeft;
        case SCIFullscreenDirectionRight:    return UIInterfaceOrientationMaskLandscapeRight;
        case SCIFullscreenDirectionPortrait: return UIInterfaceOrientationMaskPortrait;
        case SCIFullscreenDirectionOff:      break;
    }
    return 0;
}

/// Marks the next fullscreen transition as belonging to one trigger.
static void SCIArm(SCIFullscreenSource source) {
    NSString *key = (source == SCIFullscreenSourceButton)
        ? SCIPrefFullscreenButton : SCIPrefFullscreenSwipe;

    // Nothing armed when the setting is off, so a user who set only the button never has the
    // swipe answered differently by an arming that was left lying around.
    if (SCIPrefNumber(key) == SCIFullscreenDirectionOff) return;

    sciArmedSource = source;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCIArmedWindow * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Only if nothing newer took over -- two taps inside the window must not have the
        // first one's expiry cancel the second one's arming.
        if (sciArmedSource == source) sciArmedSource = SCIFullscreenSourceNone;
    });
}


%hook YTWatchViewController

- (UIInterfaceOrientationMask)allowedFullScreenOrientations {
    if (sciArmedSource == SCIFullscreenSourceNone) return %orig;

    NSString *key = (sciArmedSource == SCIFullscreenSourceButton)
        ? SCIPrefFullscreenButton : SCIPrefFullscreenSwipe;

    UIInterfaceOrientationMask forced =
        SCIMaskFor((SCIFullscreenDirection)SCIPrefNumber(key));

    if (!forced) return %orig;

    SCILogV(@"[fullscreen] forcing mask %lu for source %ld",
            (unsigned long)forced, (long)sciArmedSource);
    return forced;
}

%end


//
// Both triggers, on the class that still owns them.
//
// The button is a *toggle* -- the same method leaves fullscreen as enters it -- and that is
// harmless here: arming on the way out costs one arming that expires unused, where trying to
// tell the two apart would cost a piece of state that can get stuck.
//
%hook YTPlayerOverlayManager

- (void)didPressToggleFullscreen {
    SCIArm(SCIFullscreenSourceButton);
    %orig;
}

- (void)didSwipeToEnterFullscreen {
    SCIArm(SCIFullscreenSourceSwipe);
    %orig;
}

%end
