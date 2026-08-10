#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Features/Switches/SCITWSwitchHooks.h"
#import "Settings/SCITWGesture.h"

NSString *SCIVersionString = @"v0.1.0";  // AlbrhiTW

%ctor {
    // Defaults registered rather than assumed: reading a key that was never written
    // returns NO, which would leave the switch layer off on a fresh install -- and with
    // it off this release does nothing at all, so the tweak would appear not to have
    // installed. Registering makes the intended default explicit in one place.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefSwitchLayer: @YES,
        SCIPrefVerboseLogging: @NO,
    }];

    // Unconditional, and the only line here that is.
    //
    // Both other tweaks in this repository shipped a first release where every way of
    // telling whether the dylib had loaded was behind something that had not loaded. One
    // line at launch costs nothing and means "is it even in there" is never a question.
    NSLog(@"[AlbrhiTW] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // The panel switch, before anything else. Settings › Albrhi can turn this tweak off
    // for X without uninstalling it, and off has to mean X behaves exactly as it would
    // with nothing installed -- so nothing below this line runs.
    if (!SCIPanelAllowsThisApp()) {
        SCILogV(@"switched off for this app: %@", SCIPanelGateReport());
        return;
    }

    // The gesture goes on even when the switch layer is off, and that is deliberate: it is
    // the only door to the screen that explains why nothing is happening. A tweak whose
    // diagnostics are behind the feature being diagnosed has already been shipped twice
    // here and cost a device round trip each time.
    SCITWInstallGesture();

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefSwitchLayer]) {
        SCITWInstallSwitchHooks();
    } else {
        SCILogV(@"switch layer turned off in settings");
    }
}
