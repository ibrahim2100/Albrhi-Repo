#import "shared/src/SCIPanelGate.h"
#import "shared/src/SCICPPrefsKeys.h"
#import "SCILog.h"
#import "Diagnostics/SCICPDiagnostics.h"
#import "Features/Audio/SCICPAudioHooks.h"
#import "Features/Dashboard/SCICPScreenWatch.h"

NSString *SCIVersionString = @"v0.2.0";  // AlbrhiCP

///
/// One dylib, two processes.
///
/// SpringBoard is where the CarPlay screen connects, and it is the process any future
/// dashboard has to run in -- see SCICPScreenWatch.h for exactly how far that goes
/// today and why it stops where it does. Camera is where the recording-audio fix runs.
/// Neither process needs what the other one installs, so the constructor reads its own
/// bundle identifier and only ever sets up the half that belongs to it.
///
/// The master switch is asked for by name (SCIPanelAllowsApp), not by this process's
/// own bundle identifier (SCIPanelAllowsThisApp) -- CarPlay is one tweak with one switch
/// in the panel, and asking by the calling process's identity would split it into two
/// unrelated answers, "is SpringBoard on" and "is Camera on", for a question that only
/// has one meaning here.
%ctor {
    NSLog(@"[AlbrhiCP] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    if (!SCIPanelAllowsApp(SCICPBundleIdentifier)) {
        SCILogV(@"disabled by preference — nothing installed");
        return;
    }

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    if ([bundleID isEqualToString:@"com.apple.springboard"]) {
        [SCICPScreenWatch start];
    } else if ([bundleID isEqualToString:@"com.apple.camera"]) {
        SCICPInstallAudioHooks();
    }

    [SCICPDiagnostics writeReportToFile];
}
