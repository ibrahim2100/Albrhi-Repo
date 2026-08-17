#import "Tweak.h"
#import "Prefs.h"
#import "SCILog.h"

NSString *SCIVersionString = @"v0.1.0";  // AlbrhiTT

///
/// The scaffold. No feature lives here yet -- see CLAUDE.md for what this tweak is
/// waiting on: a real class dump and a real IPA of the current TikTok build, so every
/// hook this project ever writes is confirmed against what actually exists rather than
/// guessed from BHTikTok's own source, which targets a TikTok build years older than
/// whatever is current now.
///

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SCIPrefVerboseLogging: @NO,
    }];

    NSLog(@"[AlbrhiTT] %@ loaded into %@ (scaffold — no features yet)", SCIVersionString,
          [[NSBundle mainBundle] bundleIdentifier]);

    if (!SCIPanelAllowsThisApp()) {
        SCILogV(@"switched off for this app: %@", SCIPanelGateReport());
        return;
    }

    // Nothing to install yet.
}
