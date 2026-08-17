//
//  SCITTAdBlock.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks AWEAwemeModel so a feed item the server itself marked as an ad never becomes an
/// object at all. Safe to call unconditionally.
void SCITTInstallAdBlock(void);
