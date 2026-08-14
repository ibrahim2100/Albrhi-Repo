//
//  SCIYTHostPlayer.h
//  Albrhi for YouTube
//
//  YouTube's own player, so ours can stop it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@interface SCIYTHostPlayer : NSObject

/// Pauses whatever YouTube is playing, if anything is.
///
/// Called when our player takes over. Nothing resumes it afterwards on purpose: coming out
/// of a saved video and having the feed start talking at you is not what closing a player
/// asks for.
+ (void)pauseHost;

/// The id of the video YouTube's own player is actually on, or nil.
///
/// Nil is a real answer and the callers have to treat it as one: it means no player has
/// played yet, or this build does not answer -currentVideoID. Either way the question
/// "is this the video being watched" cannot be answered, and a caller must fall back to
/// what it would have done without an answer rather than guess one.
+ (nullable NSString *)activeVideoID;

@end
