//
//  SCITTExtras.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// The account limit, the recall of a received message, and a local record of profile visitors.
///
/// **Three features that share nothing but their provenance**: each was confirmed against the real
/// 46.4.0 binary before a hook was written, and each installs only if the runtime encoding matches
/// what it was compiled against.
void SCITTInstallExtras(void);

/// Everything the visitor log has remembered, newest first, for the settings screen and the report.
NSArray<NSString *> *SCITTVisitorLog(void);

/// What each of the three did, or why it stood down — one line per feature.
NSString *SCITTExtrasReport(void);
