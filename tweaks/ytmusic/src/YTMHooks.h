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

/// The speed control YouTube Music ships and hides. Carried over from YTMEnhanced, GPLv3.
void SCIYTMInstallPlaybackRate(void);

/// Previous/next become seek back/forward, with the original behaviour on a long press.
void SCIYTMInstallSeekButtons(void);

/// Autoplay radio after the queue ends, refused on every class that decides it.
void SCIYTMInstallAutoPlay(void);

/// Casting to a device, enabled where the app gates it.
void SCIYTMInstallCast(void);

/// The history, cast and filter buttons in the navigation bar, hidden on request.
void SCIYTMInstallNavBar(void);

/// A true-black theme, including the keyboard.
void SCIYTMInstallColours(void);

/// SponsorBlock, for the one category a music app has: `music_offtopic`.
///
/// **It asks sponsor.ajay.app what a video contains, which is a third party learning what is
/// being played.** Off unless switched on, and its row says so -- the same line this project drew
/// at tikwm.com in the TikTok tweak rather than letting a privacy cost arrive quietly.
void SCIYTMInstallSponsorBlock(void);
