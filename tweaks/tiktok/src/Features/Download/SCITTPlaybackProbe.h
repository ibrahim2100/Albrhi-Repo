//
//  SCITTPlaybackProbe.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs the playback-selection probe, or stands down if the class is absent.
extern void SCITTInstallPlaybackProbe(void);

/// What the player was offered and what it chose — the one comparison that settles whether a
/// better gear exists than the one the download takes.
extern NSString *SCITTPlaybackReport(void);

NS_ASSUME_NONNULL_END
