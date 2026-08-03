//
//  SCIYTShortsButton.h
//  Albrhi for YouTube
//
//  The save button's target in Shorts.
//
//  Declared so the button can name it. A class object is the target rather than the overlay
//  view, because Shorts recycles its overlays between one clip and the next and a target
//  pointing at a reused view would save whichever video that view now belongs to.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@interface SCIYTShortsSaver : NSObject
/// Opens the save sheet for the Short on screen.
+ (void)save;
@end
