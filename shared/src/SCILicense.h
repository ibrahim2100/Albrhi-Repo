//
//  SCILicense.h
//  Albrhi — shared
//
//  Whether this device is licensed, and what to say when it is not.
//
//  ── What this is honest about ──────────────────────────────────────────────────────────
//
//  **No check that runs on the user's own device can be made unbreakable, and this one is not
//  advertised as such.** The tweak is a dylib on a jailbroken phone; whoever holds the phone
//  holds the file, and a determined person patches the branch. Every commercial tweak with a
//  licence has been cracked, including the ones written by people who do this full time.
//
//  What a licence layer can actually buy:
//
//    1. **Most people do not crack anything.** They pay, or they go without. A lock that a
//       specialist opens in an hour still works on everybody who is not that specialist.
//    2. **Cost.** Verification that is spread out, tied to a real signature and consulted from
//       several places is meaningfully more work to remove than one `if` at launch.
//    3. **Revocation**, which is the part no client-side trick provides: a key that turns up on
//       a forum is named in a list and stops working on every device that reaches the server.
//
//  What it cannot buy is certainty, and building as though it could is how a licence layer ends
//  up breaking things for paying users while the crack circulates anyway. So: it fails toward
//  letting people work, it never crashes an app, and it never blocks on the network.
//
//  ── The design ────────────────────────────────────────────────────────────────────────
//
//  **A signed key that works with no internet, plus a check-in that can revoke it.**
//
//  The key is `ALB1.<payload>.<signature>` — ECDSA P-256 over SHA-256, verified against a public
//  key compiled into every binary. The payload names the device it was issued to and the day it
//  expires. Nothing about it is secret: a licence the buyer can read is one the buyer can check.
//
//  The device is named by a **derived fingerprint** — sixteen hex characters of
//  SHA-256(serial + model + a fixed salt). It is stable across reinstalls and tweak updates,
//  needs nothing written to disk to compute, and is not reversible into a serial number by
//  anyone who receives it. That was the owner's own choice over sending a real UDID.
//
//  Revocation is a periodic call carrying only the licence id and that fingerprint. **One day of
//  grace** if it cannot be reached — the owner's decision, and worth restating plainly because
//  it is short: a phone in airplane mode for two days stops being licensed, which is a support
//  question rather than a bug. `SCILicenseGraceSeconds` below is the one place to change it.
//
//  ── Enforcement is off in this release, deliberately ───────────────────────────────────
//
//  `SCILicenseIsEnforced()` answers NO unless the panel's own switch is on. The source has been
//  public and free the whole time it has existed; turning a gate on in the same release that
//  introduces it would break every existing install on update, before a single key has been
//  issued. So this ships measuring: the panel shows the fingerprint, a key can be entered and is
//  really verified, and nothing is withheld from anyone until that switch is flipped on purpose.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// How this device answers when a key is issued for it. Sixteen lowercase hex characters.
///
/// Never nil: a device whose serial cannot be read still gets a fingerprint from what can be
/// read, and `SCILicenseFingerprintIsWeak()` says so rather than the fingerprint silently
/// meaning less than it looks like it does.
NSString *SCILicenseFingerprint(void);

/// YES when the fingerprint had to be built without a device-unique value.
///
/// A key issued against a weak fingerprint is a key that fits every phone of that model. Worth
/// knowing before issuing one, which is why the panel prints it beside the fingerprint.
BOOL SCILicenseFingerprintIsWeak(void);

typedef NS_ENUM(NSInteger, SCILicenseState) {
    SCILicenseStateNone = 0,      ///< No key has been entered.
    SCILicenseStateValid,         ///< Signed for this device and in date.
    SCILicenseStateExpired,       ///< Genuine, and its day has passed.
    SCILicenseStateWrongDevice,   ///< Genuine, issued to a different fingerprint.
    SCILicenseStateMalformed,     ///< Not a key at all, or edited.
    SCILicenseStateRevoked,       ///< The server named it.
    SCILicenseStateGrace,         ///< Valid, and the check-in has not succeeded lately.
};

/// The state of the key stored for this device, recomputed on demand.
SCILicenseState SCILicenseCurrentState(void);

/// The one question the tweaks ask.
///
/// YES when enforcement is off (which is the shipped default), and YES when there is a valid
/// key. So a build that has never been given a key behaves exactly as every release before the
/// licence layer existed — which is the direction this has to fail in.
BOOL SCILicenseAllows(void);

/// Whether the gate is actually being applied on this device.
BOOL SCILicenseIsEnforced(void);

/// A human sentence for the panel and for the diagnostics report.
NSString *SCILicenseStatusLine(void);

/// The same sentence for a state that is not the stored one.
///
/// Needed because a key that was *rejected* was never stored: asking for the status line after a
/// refusal would describe whatever key was there before, and tell somebody their brand-new key
/// expired when what actually happened is that it was issued to their other phone. Three
/// refusals need three different things done about them.
NSString *SCILicenseDescribeState(SCILicenseState state);

/// Stores a key after checking it. NO if it is not a key for this device, with `outState` set.
BOOL SCILicenseStoreKey(NSString *key, SCILicenseState *_Nullable outState);

/// The stored key, or nil.
NSString *_Nullable SCILicenseStoredKey(void);

/// Removes it.
void SCILicenseForgetKey(void);

/// Asks the server whether the stored key is still good, at most once every few hours.
///
/// Never blocks: it returns immediately and the answer lands in the stored state for the next
/// question. Called from the panel and once per launch from the gate.
void SCILicenseCheckInIfDue(void);

/// One day, in seconds. The owner's choice, and the single place it lives.
extern const NSTimeInterval SCILicenseGraceSeconds;

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
