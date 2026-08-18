//
//  SCITTPlaybackProbe.x
//  Albrhi for TikTok
//
//  Retired. Kept as a file so its lesson stays where the mistake was made.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCITTPlaybackProbe.h"

///
/// **This probe crashed TikTok repeatedly and the hook is gone.**
///
/// It hooked `AWEVideoPlayBitrateControler`'s selection method with a signature I wrote from
/// the selector name alone — `(double)duration`, `(NSInteger)trategyType`, returning `id`. None
/// of that was read from the runtime. **A `%hook` whose argument types do not match the real
/// method does not fail politely**: the arguments arrive in the wrong registers and of the
/// wrong widths, and the process dies. It is the same mistake as reading `-bitRate` through a
/// guessed `long long` cast, which crashed 0.12.0 and is written down in this project's own
/// rules — made again, in the one file whose whole purpose was to stop guessing.
///
/// A hook of that kind needs `method_getTypeEncoding` on the real method, compared against what
/// is about to be declared, and must stand down on any mismatch. Nothing here needs it now:
/// **the probe already answered its question** — `bitrateModels` carries the same gear names at
/// a quarter of the player's bitrate — and 0.16.0 reads the player's own models from
/// `__playBSModel` on the video model this tweak already holds, which requires no hook at all.
///
/// The measurement was worth it. Shipping it without checking the signature was not.
void SCITTInstallPlaybackProbe(void) {
    // Nothing. Deliberately.
}

NSString *SCITTPlaybackReport(void) {
    return @"retired — it crashed the app, and 0.16.0 reads the player's own ladder directly";
}
