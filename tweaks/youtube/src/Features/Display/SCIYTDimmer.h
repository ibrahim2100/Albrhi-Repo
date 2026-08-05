//
//  SCIYTDimmer.h
//  Albrhi for YouTube
//
//  Screen brightness below what the slider allows.
//
//  iOS stops the brightness slider well above black, which on an OLED phone in a dark room
//  is still far too bright. Nothing here touches the backlight -- there is no supported way
//  to go below the system minimum -- so it does the only honest thing available: a black
//  layer over everything, at a chosen opacity. On an OLED panel that is close to the same
//  result; on an LCD it is a dimmer picture rather than a dimmer screen, and the setting
//  says so.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTDimmer : NSObject

/// Starts watching the settings and the clock. Safe to call more than once.
+ (void)start;

/// Applies the current settings right now.
///
/// Called by the settings screen the moment a switch moves, so the effect is visible while
/// the panel is still open -- a brightness setting you cannot see take effect is a setting
/// nobody can judge.
+ (void)refresh;

/// Whether the schedule says it is night at a given minute of the day.
///
/// Its own method, taking the minute rather than reading the clock, because a range that
/// wraps midnight is the one piece of arithmetic here that can be wrong and the only way to
/// be sure of it is to be able to ask it about a time that is not now.
+ (BOOL)isNightAtMinute:(NSInteger)minuteOfDay start:(NSInteger)start end:(NSInteger)end;

@end

NS_ASSUME_NONNULL_END
