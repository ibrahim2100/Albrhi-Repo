//
//  SCIYTArtwork.h
//  Albrhi for YouTube
//
//  Writing the cover into the sound file itself.
//
//  The cover already showed in the list, in the player and on the lock screen, because all
//  three read it from a picture kept beside the file. None of that is in the file. Send the
//  song to someone, open it in another app, put it on a computer, and it is a nameless
//  untitled thing again -- which is the moment a saved song most wants to know what it is.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@class SCIYTJob;

@interface SCIYTArtwork : NSObject

/// Writes the cover and the title into a saved audio file, in place.
///
/// Does nothing for video: an .mp4 carries its picture in its own frames, and rewriting a
/// few hundred megabytes to add a still nobody will see is not worth the wait or the wear.
///
/// Nothing is re-encoded. The sound is passed through untouched and only the tags around it
/// are rewritten, so this is quick and costs no quality. If it fails at any point the
/// original is left exactly as it was -- a song with no cover is a small disappointment, a
/// song replaced by a broken file is not.
+ (void)embedInto:(SCIYTJob *)job completion:(void (^)(BOOL ok))completion;

@end
