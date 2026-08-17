#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Features/Ads/SCITTAdBlock.h"
#import "Features/Bypass/SCITTBypass.h"
#import "Features/Privacy/SCITTPrivacy.h"
#import "Features/Download/SCITTButton.h"
#import "Settings/SCITTGesture.h"

NSString *SCIVersionString = @"v0.4.12";  // AlbrhiTT

///
/// TESTED ON TikTok 46.4.0. Every class here was confirmed present in that build's own
/// MusicallyCore.framework binary before being hooked -- read directly, not carried
/// over from BHTikTok's own source, which this was read for architecture only. See
/// CLAUDE.md and this tweak's own CHANGELOG.md for what that reading found.
///

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefHideAds: @YES,
        SCIPrefDownloadButton: @YES,
        SCIPrefBypass: @YES,
        SCIPrefPrivacyStory: @YES,
        SCIPrefPrivacyMessages: @YES,
        SCIPrefPrivacyProfile: @YES,
        SCIPrefVerboseLogging: @NO,
    }];

    NSLog(@"[AlbrhiTT] %@ loaded into %@", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    // The gesture goes on even when every feature below it is off, so the status
    // screen that explains why nothing is happening is always reachable -- the same
    // rule the other tweaks in this repository follow.
    SCITTInstallGesture();

    if (!SCIPanelAllowsThisApp()) {
        SCILogV(@"switched off for this app: %@", SCIPanelGateReport());
        return;
    }

    SCITTInstallAdBlock();
    SCITTInstallBypass();
    SCITTInstallPrivacy();
    SCITTInstallButton();
}
