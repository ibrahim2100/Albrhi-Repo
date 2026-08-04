//
//  SCIYTPalette.h
//  Albrhi for YouTube
//
//  The colours a cover is actually made of.
//
//  This is the one thing that makes a music screen feel alive rather than assembled: the
//  background is not a colour somebody chose, it is *this song's* colour, pulled out of its
//  own artwork. Every track dresses its own screen, and nothing about it has to be designed
//  twice.
//
//  Cheap on purpose. The cover is drawn once into a 12x12 bitmap -- 144 pixels -- and the
//  answer comes from those. A phone should not spend real time deciding what colour to make
//  a gradient, and at that size the work is invisible next to the image decode that had to
//  happen anyway.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTPalette : NSObject

/// The two colours to build a background from, dark end first.
///
/// Always returns something: a cover that is entirely grey, or missing altogether, gets a
/// neutral pair rather than nil, so no caller has to carry a fallback of its own.
///
/// Both are darkened to a fixed ceiling. A bright cover would otherwise produce a background
/// that white text cannot be read on -- and legibility is not something to leave to whichever
/// album happens to be playing.
+ (NSArray<UIColor *> *)backgroundFor:(nullable UIImage *)image;

/// The accent to draw a scrubber and controls in, from the same cover.
///
/// Lifted in saturation and pinned in brightness, because the useful colour in a cover is
/// rarely the most common one -- most covers are mostly dark -- and a control has to stand
/// out from the background this same palette produced.
+ (UIColor *)accentFor:(nullable UIImage *)image;

/// A square cover, built from a picture that is not square.
///
/// YouTube's stills are 16:9 and the lock screen's artwork slot is a square, so handing it
/// one directly gets it letterboxed — a wide strip with black above and below, which is what
/// every saved song and video has looked like there.
///
/// This fills the square with the picture's own colours and sets the picture on top of them,
/// whole and uncropped. Cropping to square was the other option and it is worse: a thumbnail
/// is composed for its own shape, and taking the middle third of one routinely removes the
/// face, the title, or whatever the picture was of.
+ (nullable UIImage *)squareArtwork:(nullable UIImage *)image side:(CGFloat)side;

@end

NS_ASSUME_NONNULL_END
