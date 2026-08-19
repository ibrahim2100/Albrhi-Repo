#import <Foundation/Foundation.h>
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "Pairing/SCIWPairing.h"

NSString *SCIVersionString = @"v0.1.0";  // AlbrhiWatch

///
/// Albrhi Watch — pairing an Apple Watch whose watchOS is newer than this iPhone expects.
///
/// The pairing core is `watched` by 34306, MIT (see LICENSE-watched and CHANGELOG.md). This file
/// is the part that is this project's: the defaults, the gate, and the decision about what runs.
///
/// **The defaults live in the reader, not in a registration call.** `registerDefaults:` applies to
/// `standardUserDefaults`, and nothing here reads that: the switches live in a shared CFPreferences
/// domain so Settings and SpringBoard can both see them (see Prefs.h). A default registered where
/// nothing looks is a default that never applies.
///
/// The three feature switches default *on* so turning the one master switch on gives a working
/// tweak rather than a scavenger hunt through three more -- the split Albrhi NextUp settled on.
/// The master itself is off until somebody turns it on, which for a tweak that answers pairing
/// questions is the only defensible default.
///
%ctor {
    @autoreleasepool {
        NSLog(@"[AlbrhiWatch] %@ loaded into %@", SCIVersionString,
              [[NSBundle mainBundle] bundleIdentifier]);

        // The panel's switch first, then this tweak's own master. Neither installs anything on
        // its own: a group that is never %init-ed is a hook that was never placed, which is the
        // only stop that cannot leave the pairing stack half-answered.
        if (!SCIPanelAllowsThisApp()) return;
        if (!SCIWReadPreference(SCIWPrefEnabled, NO)) return;

        SCIWInstallPairing();
    }
}
