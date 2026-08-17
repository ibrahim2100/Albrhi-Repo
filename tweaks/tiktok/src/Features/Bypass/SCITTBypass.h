//
//  SCITTBypass.h
//  Albrhi for TikTok
//
//  Answers TikTok's own anti-tamper and jailbreak-detection checks the way an
//  unmodified phone would. Touches nothing about payment or subscriptions -- the same
//  line Locket's own bypass keeps, and for the same reason.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks every confirmed detection point, each guarded by its own class check. Safe to
/// call unconditionally.
void SCITTInstallBypass(void);
