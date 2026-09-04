//
//  SCIYTLaunchGuard.h
//  Albrhi for YouTube
//
//  **A tweak may cost a feature. It may not cost the app.**
//
//  YouTube stopped launching: it sat on its own logo for ever, with no crash and no log, and
//  turning Albrhi's YouTube switch off opened it instantly. Two releases were spent reading code
//  for the cause — three real faults were found and fixed and it still hung — which is the point
//  at which the shape of the problem matters more than its identity: **anything of ours that can
//  keep the app from finishing its launch must be able to give up.**
//
//  So the guard watches for the app becoming active. If that has not happened within a few
//  seconds of the tweak loading, everything expensive stands down for the rest of the session:
//  the feed filter, the tab painting, the player overlay, the progress-bar markers. The app
//  finishes launching, YouTube behaves as if the tweak were switched off, and the diagnostics
//  page says so in as many words rather than leaving somebody to guess why the ads came back.
//
//  Two details it would be easy to get wrong:
//
//    - **The timer is on a background queue.** A main-queue timer cannot fire while the main
//      thread is the thing that is stuck, which is precisely the case being guarded against.
//    - **The flag is read, never waited on.** Each hook asks a boolean and returns `%orig`; a
//      guard that took a lock would be a new way to hang the app it exists to protect.
//

#import <Foundation/Foundation.h>

/// Starts watching. Called once, from `%ctor`, before anything else.
void SCIYTLaunchGuardStart(void);

/// YES once the guard has given up on this launch — every expensive hook checks it and does
/// nothing. Answers NO for the whole of a normal session.
BOOL SCIYTStoodDown(void);

/// What the guard has to say, for the diagnostics page.
NSString *SCIYTLaunchGuardReport(void);

/// YES once the app has finished launching and become active.
///
/// **The launch is the one part of the process nothing of ours may be inside.** Work done here is
/// work done before the app has drawn anything, with iOS's own watchdog counting — and a fault
/// costs the whole app rather than the feature. Anything that can wait asks this instead, and
/// what it buys is the difference between a tweak that cannot be uninstalled without a computer
/// and one that is merely slow until it is switched off.
BOOL SCIYTAppIsActive(void);

/// Runs `block` on the main queue as soon as the app is active — now, if it already is.
///
/// Used once, and it is the reason the tab bar can be changed at all: the change is the same
/// change, made a second later, at a moment when getting it wrong is survivable.
void SCIYTWhenActive(void (^block)(void));
