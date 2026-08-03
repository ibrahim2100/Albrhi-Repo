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

#import <UIKit/UIKit.h>

@interface SCIYTShortsSaver : NSObject
/// Opens the save sheet for the Short this button belongs to.
///
/// Takes the button rather than nothing, because which clip to save is answered by the
/// overlay the button is sitting on -- not by whichever clip YouTube last announced, which
/// during Shorts is routinely the one queued below.
+ (void)saveFrom:(UIButton *)button;
@end
