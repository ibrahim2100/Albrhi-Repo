#import "shared/src/SCIPanelGate.h"
#import "shared/src/SCICPPrefsKeys.h"
#import "SCILog.h"
#import "Diagnostics/SCICPDiagnostics.h"
#import "Features/Audio/SCICPAudioHooks.h"
#import "Features/Dashboard/SCICPScreenWatch.h"
#import "Features/Bridge/SCICPAdmissionSpoof.h"
#import "Features/Wallpaper/SCICPWallpaperHooks.h"

NSString *SCIVersionString = @"v0.4.1";  // AlbrhiCP

///
/// One dylib, three processes.
///
/// SpringBoard is where the CarPlay screen connects and where the admission spoof
/// runs. Camera is where the recording-audio fix runs. com.apple.CarPlayWallpaper is
/// Apple's own hidden system app that renders the dashboard background -- see
/// SCICPWallpaperHooks.h for how that was found and what runs there. None of the
/// three needs what the others install, so the constructor reads its own bundle
/// identifier and only ever sets up the one that belongs to it.
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
        SCICPInstallAdmissionSpoof();
    } else if ([bundleID isEqualToString:@"com.apple.camera"]) {
        SCICPInstallAudioHooks();
    } else if ([bundleID isEqualToString:@"com.apple.CarPlayWallpaper"]) {
        SCICPInstallWallpaperHooks();
    }

    [SCICPDiagnostics writeReportToFile];
}
