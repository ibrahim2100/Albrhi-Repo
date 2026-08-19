#import <Foundation/Foundation.h>
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "Pairing/SCIWPairing.h"
#import "Update/SCIWUpdateGuard.h"
#import "Update/SCIWUpdateProbe.h"

NSString *SCIVersionString = @"v0.2.0";  // AlbrhiWatch

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
        NSString *process = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSLog(@"[AlbrhiWatch] %@ loaded into %@", SCIVersionString, process);

        // The panel's switch first, then this tweak's master. Neither installs anything on its
        // own: a group never %init-ed is a hook never placed, which is the only stop that cannot
        // leave a pairing stack half-answered.
        if (!SCIPanelAllowsThisApp()) return;
        if (!SCIWReadPreference(SCIWPrefEnabled, NO)) return;

        //
        // **Two processes, two jobs, and neither runs the other's.**
        //
        // Pairing is answered inside SpringBoard: that is where NanoRegistry is asked, and where
        // the preference writes belong. The update surface is inside the Watch app and nowhere
        // else. Installing both everywhere would put hooks in a process that never calls them --
        // harmless until the day one of those classes means something different there.
        //
        if ([process isEqualToString:@"com.apple.springboard"]) {
            SCIWInstallPairing();
        } else if ([process isEqualToString:@"com.apple.Bridge"]) {
            SCIWInstallUpdateGuard();
        }

        // The probe runs in both, and hooks nothing. Its whole job is to report what the classes
        // in *this* process really look like, so the next feature is written from a device's
        // answer rather than from a name in a binary.
        SCIWRunUpdateProbe();
    }
}
