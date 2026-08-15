//
//  SCITWActionBarButton.h
//  Albrhi for X
//
//  The save button on X's own inline action bar — the row with reply, repost, like
//  and share, which X draws both under a timeline post and over a playing video.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Installs the hook, if this build has the bar.
void SCITWInstallActionBarButton(void);

/// What it did, for the diagnostics page. Distinguishes a missing class from an installed
/// hook that found no media, because those look identical from the outside and have
/// nothing in common as fixes.
NSString *SCITWActionBarButtonReport(void);

#ifdef __cplusplus
}
#endif
