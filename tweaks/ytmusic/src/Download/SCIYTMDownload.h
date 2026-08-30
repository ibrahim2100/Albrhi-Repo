//
//  SCIYTMDownload.h
//  Albrhi for YouTube Music
//
//  Saving a track, through the button the app already has.
//
//  **Measured before it was built, and the measurement changed the plan twice.**
//
//  The stream comes from `streamingData.hlsManifestURL` in the player response -- the same source
//  the YouTube tweak here already reads, so there is no SABR wall in this app and no client to
//  impersonate. And the upstream port's whole use of FFmpeg is `-i <hls> -c copy out.m4a`: a
//  **stream copy**, not a re-encode. That is `AVAssetExportPresetPassthrough`, which is already how
//  every download in this repository is joined. **Sixteen megabytes of dependency for one remux was
//  the thing worth measuring**, and the answer was that it buys nothing here.
//
//  The button is the app's own download badge. YouTube Music draws it and gates it behind Premium;
//  the tap is intercepted before that gate rather than a second button being placed beside it --
//  which also means it appears exactly where somebody already looks for it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Node keys this tweak has seen a tap on, newest last. Shown on the Downloads screen when nothing
/// has been saved, because *what is the download badge called on this build* is the only question a
/// failure here raises.
NSArray<NSString *> *SCIYTMSeenKeys(void);

/// Records one, ignoring repeats.
void SCIYTMRememberKey(NSString *key);

/// One line saying what the interception has actually done.
///
/// **Three failures wear the same face here — the Premium prompt** — and until now the empty
/// Downloads screen could not tell them apart: the hook not installing at all, the hook installing
/// and never being called, or being called on every tap and never recognising the badge. Each needs
/// a different next step, so each is counted separately.
NSString *SCIYTMDownloadReport(void);

/// How many times the install was attempted. One means the constructor was enough.
NSUInteger SCIYTMInstallAttempts(void);

/// Intercepts the app's own download badge on the now-playing screen.
void SCIYTMInstallDownload(void);

NS_ASSUME_NONNULL_END
