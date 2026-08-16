#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Features/Bypass/SCILKBypass.h"
#import "Features/Media/SCILKMediaHooks.h"
#import "Settings/SCILKGesture.h"
#import "UI/SCILKWelcome.h"

NSString *SCIVersionString = @"v0.3.0";  // AlbrhiLK

%ctor {
    // Defaults registered rather than assumed: reading a key that was never written returns
    // NO, which would leave the bypass off on a fresh install -- and with it off this tweak
    // does nothing, so it would appear not to have installed. Registering makes the intended
    // default explicit in one place.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefBypass: @YES,
        SCIPrefSaveMoments: @YES,
        SCIPrefVerboseLogging: @NO,
    }];

    // Unconditional, and the only line here that is. Every other tweak in this repository
    // shipped a first release where the one way to tell whether the dylib had loaded was
    // behind something that had not loaded; one line at launch settles it for good.
    NSLog(@"[AlbrhiLK] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // The panel switch, before anything else. Settings > Albrhi can turn this tweak off for
    // Locket without uninstalling it, and off has to mean the app behaves exactly as it
    // would with nothing installed -- so no hook below this line is even registered.
    //
    // SCIPanelAllowsThisApp() itself is what actually decides this correctly for a
    // self-contained sideload build too, where there is no panel to ask at all -- see
    // shared/src/SCIPanelGate.m for why "absent" answers differently there.
    if (!SCIPanelAllowsThisApp()) {
        SCILogV(@"switched off for this app: %@", SCIPanelGateReport());
        return;
    }

    // The gesture goes on even when the bypass itself is off, so the status screen that
    // explains why nothing is happening is always reachable -- the same rule the other
    // tweaks follow after each shipped a diagnostics page behind the feature it diagnoses.
    SCILKInstallGesture();

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefBypass]) {
        SCILKInstallBypass();
    } else {
        SCILogV(@"bypass turned off in settings");
    }

    // Saving moments is independent of the bypass: the two answer different needs, and
    // turning one off to rule it out of a problem should not take the other with it.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefSaveMoments]) {
        SCILKInstallMediaHooks();
    } else {
        SCILogV(@"moment saving turned off in settings");
    }

    // Said once, on the first launch after installing. Deliberately after everything
    // else in here: a greeting must never be the reason a hook did not get installed.
    [SCILKWelcome showIfFirstRun];
}
