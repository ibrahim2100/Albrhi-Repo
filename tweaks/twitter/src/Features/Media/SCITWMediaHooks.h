//
//  SCITWMediaHooks.h
//  Albrhi for Twitter
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Attaches the media capture, if this build of X has the model class it reads. Safe to
/// call when it does not: it attaches nothing and says so in the log.
void SCITWInstallMediaHooks(void);
