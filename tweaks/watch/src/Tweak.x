#import <Foundation/Foundation.h>
#import "Prefs.h"
#import "Localization/SCILocalize.h"
#import "Pairing/SCIWPairing.h"
#import "Update/SCIWUpdateGuard.h"
#import "Update/SCIWUpdateProbe.h"
#import "Bridge/SCIWBridgeSignal.h"

NSString *SCIVersionString = @"v0.2.8";  // AlbrhiWatch

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

        //
        // **The probe runs before the gate, and that is deliberate.**
        //
        // It hooks nothing and changes nothing -- it asks the runtime what its own classes look
        // like. Running it only when the tweak is switched on made an empty report ambiguous
        // between "the master is off", "the gate refused" and "the classes are missing", and the
        // first device report was exactly that ambiguity: nothing worked and nothing said why.
        //
        SCIWRunUpdateProbe();

        //
        // **An empty section and a denied write look identical, and one bit separates them.**
        //
        // The Watch app is sandboxed; SpringBoard is not. So the Watch app announces whether its
        // own report survived being written, and SpringBoard -- which can always write -- records
        // the answer. Both sides sit above the gate for the same reason the probe does: a report
        // that only exists when everything already works diagnoses nothing.
        //
        if ([process isEqualToString:@"com.apple.springboard"]) SCIWBridgeListen();
        if ([process isEqualToString:@"com.apple.Bridge"])      SCIWBridgeAnnounce();

        // The master switch, and nothing above it. Albrhi Panel's per-app switch is *not* asked:
        // it reads app_enabled_<bundleid>, no switch anywhere sets that for SpringBoard or the
        // Watch app, and asking it refused forever. See Prefs.h.
        if (!SCIWReadPreference(SCIWPrefEnabled, NO)) return;

        //
        // **The pairing answers go into every process that asks them.**
        //
        // The first build installed them in SpringBoard alone, on the reasoning that pairing is
        // "SpringBoard's job". Answering wherever the question is asked costs nothing and cannot
        // be wrong in one process while right in another. **It is not, however, what fixed the
        // Watch app** -- see CHANGELOG.md 0.2.4: a device opened it on 0.2.1, with the hooks in
        // SpringBoard alone, after a full userspace restart. What fixes it is the NanoRegistry
        // preference writes plus every process restarting to read them.
        //
        SCIWInstallPairing();

        // The update surface exists only in the Watch app: SUBManager is not in SpringBoard at
        // all, which the probe confirmed rather than assumed.
        if ([process isEqualToString:@"com.apple.Bridge"]) {
            SCIWInstallUpdateGuard();

            // **Announced twice on purpose.** The first drop happens above the gate, so a report
            // exists even when the tweak is switched off; this one replaces it once the update
            // hold has decided, because its verdict is written by this same sandboxed process and
            // cannot reach Settings by preference any more than the report could.
            SCIWBridgeAnnounce();
        }
    }
}
