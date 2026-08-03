//
//  SCIYTDislikes.h
//  Albrhi for YouTube
//
//  The dislike count, from the Return YouTube Dislike archive.
//
//  YouTube stopped publishing the number in 2021. It is not recoverable from the app --
//  nothing in the player response carries it any more -- so it comes from returnyoutubedislike.com,
//  which has been collecting it since before the change. That is an estimate built from
//  what its users report, and the settings row says so: presenting someone else's sample
//  as YouTube's own figure would be the wrong claim to make.
//
//  Nothing is sent. This asks for a video's number and receives it; it does not report
//  what is being watched, and it does not submit votes. The upstream project offers that
//  and it is deliberately not here -- a tweak that quietly posts your viewing to a third
//  party is a different thing from one that reads a public number.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Posted when a count arrives, with the video id as the object.
extern NSNotificationName const SCIYTDislikesDidArriveNotification;

@interface SCIYTDislikes : NSObject

/// The count for a video, formatted the way YouTube writes counts, or nil.
///
/// Answers from memory when it can, which is what makes it usable from a layout pass: the
/// call happens while a node is being drawn and cannot wait for a network round trip. A
/// miss starts the fetch and returns nil, and the notification below says when to look
/// again.
+ (NSString *)cachedCountFor:(NSString *)videoID;

/// Asks for a video's number if it is not already known or already being asked for.
+ (void)prepare:(NSString *)videoID;

/// What the last request did, for the diagnostics page.
+ (NSString *)lastState;

@end
