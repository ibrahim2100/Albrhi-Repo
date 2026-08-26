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

/// Synced lyrics: a panel on the now-playing screen, fed by six providers -- LRCLib, Genius,
/// MusixMatch, NetEase, the video description, and YouTube Music's own lyrics when it has them.
///
/// **It asks outside services what is playing.** That is what a lyrics feature is, and it cannot
/// be done locally; the switch is on because it was asked for, and the package description says
/// plainly what leaves the device. Translation of those lyrics is a separate switch, off, and does
/// nothing at all without a key the user supplies.
void SCIYTMInstallSyncedLyrics(void);

/// The lyrics panel's own screen: selectable text, a source picker, timing offset, romanisation.
void SCIYTMInstallSelectableLyrics(void);

/// The settings screen itself: a row in YouTube Music's own account menu that opens Albrhi's page.
///
/// **Ten features shipped without it.** 0.2.0 and 0.3.0 carried the hooks and not the page that
/// controls them, which is a tweak with no way to reach a single option -- reported exactly that
/// way. The Premium and scrobbling rows are gone from it: one for a feature deliberately not
/// carried, one for code that is not here.
void SCIYTMInstallSettings(void);

/// The tab-bar and chip-cloud hooks the settings page switches.
void SCIYTMInstallOtherSettings(void);

/// Audio or video, and a default between them.
///
/// YouTube Music decides which of the two a track plays as, and hides the switch on most of them.
/// These hooks open it everywhere and honour a stored default -- `audioVideoMode`, 0 for audio and
/// 1 for video, which is upstream's own key and stays so the ported file remains diffable.
void SCIYTMInstallAVSwitching(void);
