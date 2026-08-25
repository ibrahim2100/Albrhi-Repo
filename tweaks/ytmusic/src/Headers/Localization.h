//
//  Localization.h
//  Albrhi for YouTube Music
//
//  **A shim, and it is load-bearing.** The carried-over lyrics module asks for `LOC(key)` and for
//  `NSBundle.ytmu_defaultBundle` by these exact names, in twenty files. Editing all of them would
//  end the one property this port is kept for -- being diffable against upstream -- so the name
//  upstream expects is provided instead, pointing at what this package actually ships.
//
//  Upstream's own `YTMULocalized(key, fallback)` already returns its inline fallback when the
//  bundle is missing, which is exactly this tweak's case: Albrhi ships no `YTMusicUltimate.bundle`,
//  so every carried-over string reads as its English fallback rather than as nil. Albrhi's own
//  strings go through SCILocalize as always.
//
#import <Foundation/Foundation.h>
#import "../Utils/NSBundle+YTMU.h"

#ifndef LOC
#define LOC(key) YTMULocalized(key, key)
#endif
