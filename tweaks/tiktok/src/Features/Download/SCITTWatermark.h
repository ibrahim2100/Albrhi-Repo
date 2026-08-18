//
//  SCITTWatermark.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs the watermark hook, or stands down if the class is absent.
///
/// Called from the tweak's own `%ctor` after the panel gate, like every other group here, so
/// "off" really means no hooks installed.
extern void SCITTInstallWatermarkHooks(void);

/// Whether the hook attached, and how many watermark decisions it has cleared.
extern NSString *SCITTWatermarkReport(void);

NS_ASSUME_NONNULL_END
