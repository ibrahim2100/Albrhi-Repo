//
//  SCIKVC.h
//  Albrhi — shared
//
//  Reading a named value off somebody else's object, without running their code.
//
//  **This exists to retire `-valueForKey:` from this repository**, and the reasoning is
//  already in CLAUDE.md at length:
//
//    - `-valueForKey:` is not a probe. It calls the real getter when one exists and reads
//      the ivar directly when one does not; raising is its last resort, not its first. A
//      follow-badge feature probed twelve guessed keys with it, on every object up the
//      responder chain, from inside `-layoutSubviews` — and changing a profile picture
//      crashed Instagram.
//
//    - `@catch` does not make that safe. It catches `NSException`. A Swift getter that
//      traps, a failed assertion, or a half-initialised object are none of those: they end
//      the process and no handler ever sees them.
//
//  What the rule asks for instead is *one selector, guarded by `-respondsToSelector:`,
//  stepping over anything that does not answer.* That is exactly what this is.
//
//  **Why it is not simply `-respondsToSelector:` plus a message send.** KVC resolves a key
//  four ways — `-key`, `-isKey`, `-getKey`, and failing all three the `_key`/`key` ivar —
//  so replacing it with a single selector check would silently stop finding values that
//  were being found before, and a BOOL property (`-isFoo`) would break first. All three
//  getters are tried here in KVC's own order.
//
//  The ivar path is kept too, and it is the one place this is *safer* than KVC rather than
//  merely equivalent: the ivar is read only when its declared type encoding says it holds
//  an object, with `object_getIvar`, which executes nothing at all. KVC would box a scalar
//  ivar into an `NSNumber` by running through its own machinery; this steps over it.
//
//  So the whole function sends at most one message the receiver has already said it
//  answers, and otherwise touches memory the runtime has described. There is no exception
//  handler here because there is nothing left to throw.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Imported from .xm and .mm files as well as .m ones, so the declarations below need C
// linkage or C++ mangles the names and the link fails with "symbol(s) not found" -- which
// is exactly what happened here, because tools/check.py's rule 15 looks for this only
// inside a tweak's own src/ and this header lives in shared/.
#ifdef __cplusplus
extern "C" {
#endif

/// The value behind `key` on `object`, or nil if the object does not offer one.
///
/// nil for a nil object, an empty key, or a key nothing on that class answers — never an
/// exception, and never a call into code the receiver has not declared.
id _Nullable SCISafeValueForKey(id _Nullable object, NSString *_Nullable key);

/// The same, read as a BOOL. Absent reads as NO.
BOOL SCISafeBoolForKey(id _Nullable object, NSString *_Nullable key);

/// The same, boxed the way `-valueForKey:` used to box it.
///
/// **This is the one thing plain `SCISafeValueForKey` deliberately will not do**, and it
/// needs its own name rather than being folded in: a getter that answers with a number is
/// a real answer of the wrong kind, and silently boxing it would hide the difference
/// between "this class has no such thing" and "it has one and it is an integer". Callers
/// that genuinely want the number — an enum compared against a case, a subtype, a count —
/// ask for it here, and the encoding decides the cast rather than the caller guessing it.
///
/// nil when nothing answers, or when what answers is not a number.
NSNumber *_Nullable SCISafeNumberForKey(id _Nullable object, NSString *_Nullable key);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
