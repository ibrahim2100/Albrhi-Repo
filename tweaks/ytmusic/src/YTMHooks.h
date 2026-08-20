//
//  YTMHooks.h
//  Albrhi for YouTube Music
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Advertising: refused where YouTube Music asks for it, and the monetisation flags its player
/// response carries. Carried over from YTMusicUltimate under GPLv3.
void SCIYTMInstallAdBlock(void);

/// Background playback: the upsell notification that interrupts it, and the playability flags
/// that gate it. Carried over from YTMusicUltimate under GPLv3.
void SCIYTMInstallBackground(void);
