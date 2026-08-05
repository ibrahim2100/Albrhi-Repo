#import "../../YouTubeHeaders.h"
#import "../../Prefs.h"

///
/// How far a double tap jumps.
///
/// YouTube fixes this at ten seconds. Ten is a reasonable default and a poor constant: a
/// lecture wants thirty, a music video wants five, and the app offers neither.
///
/// The lever was chosen from its signature, not its name — the lesson of
/// `-adjustableIncrementForView:`, which reads like a getter for exactly this and returns
/// void. What actually carries the number is
///
///     -attemptSeekByInterval:tapPoint:seekSource:      B44@0:8d16{CGPoint=dd}24i40
///                            ^^^^^^^^ double
///
/// and the animation is told separately, by
///
///     -showDoubleTapSeekFeedbackWithPoint:seekTimeInterval:direction:   v48@0:8{CGPoint=dd}16d32q40
///
/// Both are set to the same magnitude rather than multiplied, so the label on screen and the
/// distance travelled cannot drift apart however many times either is called.
///
/// Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
///

/// The chosen interval, or zero for "leave YouTube alone".
static double SCISeekSeconds(void) {
    NSInteger seconds = SCIPrefNumber(SCIPrefSeekSeconds);
    return (seconds > 0) ? (double)seconds : 0.0;
}

/// Replaces the magnitude and keeps the sign.
///
/// The sign is the direction — backwards is a negative interval — so overwriting the whole
/// value would turn every rewind into a skip forward.
static double SCIRetimed(double interval) {
    double custom = SCISeekSeconds();
    if (custom <= 0.0 || interval == 0.0) return interval;
    return (interval < 0.0) ? -custom : custom;
}


%hook YTDoubleTapToSeekController

- (BOOL)attemptSeekByInterval:(double)interval
                     tapPoint:(CGPoint)tapPoint
                   seekSource:(int)seekSource {
    return %orig(SCIRetimed(interval), tapPoint, seekSource);
}

%end


%hook YTDoubleTapToSeekView

/// The bubble that says "10 seconds".
///
/// Hooked on the view rather than on the controller method that calls it: the controller has
/// two entry points into this and the view has one, so one hook here covers both instead of
/// leaving whichever path was not thought of showing the old number.
- (void)showDoubleTapSeekFeedbackWithPoint:(CGPoint)point
                          seekTimeInterval:(double)interval
                                 direction:(NSInteger)direction {
    %orig(point, SCIRetimed(interval), direction);
}

%end
