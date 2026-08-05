#import "SCIYTDimmer.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// One window, above everything, that lets light through.
///
/// A window rather than a view added to YouTube's own hierarchy, for the reason every other
/// approach fails: the player goes fullscreen, presents sheets, and rebuilds its view tree,
/// and a view parented anywhere inside that is somewhere else a moment later. A window at a
/// level above the app is above all of it and survives every one of those.
///
/// **The opacity is capped well short of black.** A screen dimmed to nothing is a phone that
/// cannot be used to find the setting that dimmed it, and that failure would be ours and
/// unrecoverable without deleting the tweak.
///
/// Idea from fosterbarnes/YTweaks (GPLv3); the code is our own.
///

/// The most this will ever take away. Eighty-five per cent is very dark and still legible
/// enough to reach the settings panel.
static const CGFloat kSCIMaxDim = 0.85;

/// How often the schedule is re-examined.
///
/// A minute, not a second: the boundary this watches for moves once a minute, and a timer
/// firing sixty times more often than the thing it is watching is sixty times the wake-ups
/// for the same answer.
static const NSTimeInterval kSCITick = 60.0;

static UIWindow *sciWindow = nil;
static NSTimer *sciTimer = nil;

@implementation SCIYTDimmer

+ (BOOL)isNightAtMinute:(NSInteger)minuteOfDay start:(NSInteger)start end:(NSInteger)end {
    // A range that does not wrap is the easy half.
    if (start == end) return NO;
    if (start < end) return (minuteOfDay >= start && minuteOfDay < end);

    // And this is the half worth having a method for: 22:00 to 06:00 is two intervals with
    // midnight between them, and reading it as one is how a night mode ends up on all day.
    return (minuteOfDay >= start || minuteOfDay < end);
}

/// What the settings, taken together, say the opacity should be right now.
+ (CGFloat)wantedAlpha {
    if (!SCIPrefEnabled(SCIPrefDimEnabled)) return 0.0;

    if (SCIPrefEnabled(SCIPrefNightSchedule)) {
        NSDateComponents *now =
            [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                            fromDate:[NSDate date]];
        NSInteger minute = now.hour * 60 + now.minute;

        if (![self isNightAtMinute:minute
                             start:SCIPrefNumber(SCIPrefNightStart)
                               end:SCIPrefNumber(SCIPrefNightEnd)]) {
            return 0.0;
        }
    }

    CGFloat level = (CGFloat)SCIPrefNumber(SCIPrefDimLevel) / 100.0;
    if (level <= 0.0) return 0.0;
    return MIN(level, kSCIMaxDim);
}

/// The scene this app is actually showing something in.
///
/// Not the first connected scene: a scene can be connected and in the background, and a
/// window built into that one is a window nobody sees -- which reads on the phone as the
/// setting doing nothing at all.
+ (UIWindowScene *)activeScene {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }

    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)scene;
    }
    return nil;
}

+ (void)refresh {
    // Windows are UIKit, and UIKit is the main thread. The schedule tick and the settings
    // notification can both arrive from elsewhere.
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }

    CGFloat alpha = [self wantedAlpha];

    if (alpha <= 0.0) {
        // Torn down rather than hidden. A window kept alive at alert level for a feature
        // that is off is a thing that can come back by accident, and there is nothing to
        // gain: rebuilding it costs one allocation the next time it is wanted.
        sciWindow.hidden = YES;
        sciWindow = nil;
        return;
    }

    if (!sciWindow) {
        UIWindowScene *scene = [self activeScene];
        if (!scene) return;   // nothing to attach to yet; the next tick will find one

        sciWindow = [[UIWindow alloc] initWithWindowScene:scene];
        sciWindow.frame = scene.coordinateSpace.bounds;
        sciWindow.backgroundColor = [UIColor blackColor];

        // The two lines the whole thing depends on. Without the first, the screen is dimmed
        // and also dead to touch; without the second it sits under the player.
        sciWindow.userInteractionEnabled = NO;
        sciWindow.windowLevel = UIWindowLevelAlert + 100.0;

        // Never becomes key, and shows without asking to. -makeKeyAndVisible on a window
        // that must not receive events is how a keyboard ends up talking to nothing.
        //
        // Rotation needs nothing here: a window built into a scene is resized by UIKit with
        // the scene, which is the reason it is built with -initWithWindowScene: rather than
        // with a frame.
        sciWindow.hidden = NO;

        SCILogV(@"[dim] window attached to scene %@", scene);
    }

    sciWindow.alpha = alpha;
    sciWindow.hidden = NO;
}

/// One entry point for every notification and for the timer.
///
/// Its own method taking an argument rather than wiring `+refresh` up directly:
/// NSNotificationCenter and NSTimer both hand their callback an object, and a selector that
/// takes none is being called with one argument more than it declares. It happens to work on
/// this architecture, which is the worst reason there is to leave something in.
///
/// It also coalesces. NSUserDefaultsDidChangeNotification fires whenever *anything* in the
/// app writes a default, which YouTube does constantly and for its own reasons -- so the
/// work is pushed to the end of the runloop and a burst of fifty writes costs one refresh.
+ (void)settingsMayHaveChanged:(__unused id)sender {
    // Both of the calls below are scheduled on the calling thread's runloop, and a default
    // can be written from any thread at all -- one written on a queue with no runloop would
    // schedule a refresh that never arrives.
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self settingsMayHaveChanged:nil]; });
        return;
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(refresh)
                                               object:nil];
    [self performSelector:@selector(refresh) withObject:nil afterDelay:0.0];
}

+ (void)start {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];

        // Settings are plain NSUserDefaults, so this is one observer instead of a callback
        // per switch -- and it cannot fall out of step with a switch added later.
        [centre addObserver:self
                   selector:@selector(settingsMayHaveChanged:)
                       name:NSUserDefaultsDidChangeNotification
                     object:nil];

        // Coming back from the background, because the schedule may have crossed a boundary
        // while nothing was running to notice.
        [centre addObserver:self
                   selector:@selector(settingsMayHaveChanged:)
                       name:UIApplicationDidBecomeActiveNotification
                     object:nil];

        // And a new scene, because the window belongs to one and the first one may not have
        // existed when this started.
        [centre addObserver:self
                   selector:@selector(settingsMayHaveChanged:)
                       name:UISceneDidActivateNotification
                     object:nil];

        sciTimer = [NSTimer scheduledTimerWithTimeInterval:kSCITick
                                                    target:self
                                                  selector:@selector(settingsMayHaveChanged:)
                                                  userInfo:nil
                                                   repeats:YES];

        // Tolerance, so this never wakes the phone on its own account. A minute either way
        // is invisible for a boundary the user set to the nearest minute.
        sciTimer.tolerance = kSCITick / 2.0;

        [self refresh];
    });
}

@end
