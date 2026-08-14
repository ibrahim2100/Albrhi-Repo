#import "Features/Bridge/SCICPSceneHooks.h"
#import "SCILog.h"
#import "shared/src/SCIPanelGate.h"
#import "shared/src/SCICPPrefsKeys.h"

///
/// Loaded into every app that links UIKit -- see the Makefile's own comment for why
/// that filter is the only reliable way to reach "whichever app the user picks" at
/// all, and SCICPSceneBridge.h for why that is safe: every rewrite this dylib can
/// make is gated on the bundle actually being on the user's list.
///
%ctor {
    if (!SCIPanelAllowsApp(SCICPBundleIdentifier)) {
        SCILogV(@"app: CarPlay switched off — nothing installed");
        return;
    }

    SCICPInstallSceneHooks();
}
