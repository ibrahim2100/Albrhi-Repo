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

@end
