//
//  SCITTDiagnostics.h
//  Albrhi for TikTok
//
//  What actually attached, read from the running app rather than assumed from a class
//  dump made on a different machine. Settings → Diagnostics exists precisely because a
//  class dump says what exists and nothing about what actually runs.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCITTDiagnostics : NSObject

/// How many feed models were seen, and how many were dropped as ads.
+ (void)recordModelsSeen:(NSUInteger)seen droppedAsAds:(NSUInteger)dropped;
+ (NSString *)adFilterState;

/// One line per bypass hook, the first time each answers a real caller — not every
/// call, or a check asked hundreds of times a session would drown out everything else.
+ (void)recordBypassAnswer:(NSString *)which;
+ (NSString *)bypassState;

/// The whole report, for the status screen and for a paste into an issue.
+ (NSString *)report;

@end

NS_ASSUME_NONNULL_END
