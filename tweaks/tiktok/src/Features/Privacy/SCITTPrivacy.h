//
//  SCITTPrivacy.h
//  Albrhi for TikTok
//
//  Stops the app reporting back what was watched -- a story opened, a message read, a
//  profile visited -- without changing anything this device's own screen shows.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks every confirmed report-to-server point, each guarded by its own class check.
/// Safe to call unconditionally.
void SCITTInstallPrivacy(void);
