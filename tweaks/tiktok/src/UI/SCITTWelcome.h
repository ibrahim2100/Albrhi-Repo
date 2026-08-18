//
//  SCITTWelcome.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// The first-run screen: what this tweak added, and how to reach its settings.
///
/// **A tweak with no first-run screen is a tweak whose features are found by accident.** Everything
/// here is either invisible until you look for it (the two-finger hold that opens the settings) or
/// easy to mistake for TikTok's own (the download button in the rail). This says both once, in the
/// user's own language, and then never again.
///
/// **Shown once, ever — not once per version.** The stored value is the version that showed it, so a
/// later release can decide to say something if it genuinely needs to, but an ordinary update stays
/// silent: a screen that returns after every update is a screen people learn to dismiss without
/// reading, which costs the one time it mattered.
///
@interface SCITTWelcome : NSObject

/// Shows it if it has never been shown, and records that it was. Safe to call on every launch and
/// from any thread; does nothing when there is no window yet, so a caller need not know when UIKit
/// is ready.
+ (void)showIfNeeded;

/// Shows it regardless, for the row in Settings that offers it again.
+ (void)show;

@end
