//
//  SCITTProgressBar.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Installs the hook, if this build has the bar.
void SCITTInstallProgressBar(void);

/// What it did, for the diagnostics page.
NSString *SCITTProgressBarReport(void);

#ifdef __cplusplus
}
#endif
