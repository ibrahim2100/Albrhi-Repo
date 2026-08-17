//
//  SCITTCapture.h
//  Albrhi for TikTok
//
//  Catches AWEVideoModel at its own construction, which is where a real download link
//  can actually be resolved from.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks AWEVideoModel so a video's own play URL is resolved the moment that model is
/// built, rather than waiting on the aweme model's `-video` to be populated -- which a
/// device report showed is nil for the overwhelming majority of models. Safe to call
/// unconditionally.
void SCITTInstallCapture(void);
