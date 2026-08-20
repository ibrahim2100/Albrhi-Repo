//
//  SCIWBridgeSignal.h
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

///
/// One bit out of the Watch app, for the two questions its silence cannot tell apart.
///
/// The report is written into this tweak's own preference domain, and **the Watch app is
/// sandboxed while SpringBoard is not**. That is the difference this file exists for: an empty
/// section under `in com.apple.Bridge` has two completely different causes and one appearance —
/// the tweak was never injected there (per-app injection, a switch in the jailbreak), or it ran
/// perfectly and cfprefsd refused the write. CLAUDE.md's own rule about a *reading* sandboxed app
/// being answered with nothing rather than an error applies to writing in exactly the same way,
/// and the cost of confusing the two is a round trip to a device for each guess.
///
/// So the Watch app writes, **reads its own write back**, and announces the outcome over a Darwin
/// notification. A notification carries no payload, but `notify_set_state` carries a 64-bit value
/// beside the name, and one small number is precisely the size of this question. SpringBoard is
/// listening, runs unsandboxed, and writes the answer where Settings can see it.
///
/// Deliberately not libSandy. Granting the Watch app the shared preferences directory would also
/// work, and `vendor/libSandy` is in this repository for the day the Photos/Music/Maps features
/// need it — but that adds a package the user must have installed, to move a diagnostic. This
/// needs nothing and cannot fail closed: if SpringBoard is not listening, the report simply says
/// what it said before.
///
typedef NS_ENUM(uint64_t, SCIWBridgeState) {
    SCIWBridgeStateUnknown      = 0,  ///< nothing has ever announced
    SCIWBridgeStateRan          = 1,  ///< loaded, outcome of the write not established
    SCIWBridgeStateWriteWorked  = 2,  ///< loaded, and its own report read back
    SCIWBridgeStateWriteDenied  = 3,  ///< loaded, and the write did not survive — the sandbox
};

/// Called from the Watch app once the probe has written what it found.
///
/// Verifies the write by reading it back through a fresh synchronise, then announces.
void SCIWBridgeAnnounce(void);

/// Called from SpringBoard. Records whatever the Watch app announces into the shared domain,
/// which the Watch app may not be able to reach itself — the whole point.
void SCIWBridgeListen(void);
