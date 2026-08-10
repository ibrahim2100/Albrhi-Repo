#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Features/Switches/SCITWSwitchHooks.h"
#import "Features/Switches/SCITWFeatures.h"
#import "Settings/SCITWGesture.h"
#import "Features/Media/SCITWMediaHooks.h"
#import "Features/Media/SCITWInlineButton.h"

NSString *SCIVersionString = @"v0.4.0";  // AlbrhiTW

%ctor {
    // Defaults registered rather than assumed: reading a key that was never written
    // returns NO, which would leave the switch layer off on a fresh install -- and with
    // it off this release does nothing at all, so the tweak would appear not to have
    // installed. Registering makes the intended default explicit in one place.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefSwitchLayer: @YES,
        SCIPrefInlineButton: @YES,
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

    // Independent of the switch layer on purpose. Saving a video and answering X's own
    // feature switches are two different things, and someone who turned the switch layer
    // off to rule it out of a problem should not lose their downloads with it.
    SCITWInstallMediaHooks();

    // The button on the video, beside the list. Its own hook so that a build where X has
    // renamed the media view loses the button and keeps the list, and the diagnostics
    // report says which of the two attached.
    SCITWInstallInlineButton();

    if ([[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefSwitchLayer]) {
        // Before the hooks, not after. X asks its first questions while the app is still
        // launching, and a feature applied a moment later would miss them -- which is how
        // a setting comes to work everywhere except on the screen you opened the app to.
        [SCITWFeatures apply];
        SCITWInstallSwitchHooks();
    } else {
        SCILogV(@"switch layer turned off in settings");
    }
}
