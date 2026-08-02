//
//  SCIYTPlayer.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTJob.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The player for saved downloads. One screen, both kinds.
///
/// Written rather than borrowed, and that is a decision worth stating. AVPlayerViewController
/// gives a play button and a scrubber and nothing else: there is no supported way to put a
/// "next" in its transport bar, and a list of saved videos with no way to move through it is
/// a file opener, not a player.
///
/// So the controls are ours: previous, play, next, a scrubber, both times. The same screen
/// serves sound, with the video's own still standing in for artwork, because the only real
/// difference between the two is whether there is a picture to show.
///
/// **It keeps playing when the app leaves the screen.** The audio session is Playback, the
/// lock screen is given the title and the artwork, and its buttons are wired to the same
/// queue — so skipping from the lock screen skips here. For video that needs one more
/// thing: iOS stops a layer that is not on screen, so the player is taken off the layer
/// when the app goes to the background and given back when it returns. The sound never
/// stops; only the picture is put down while nobody is looking at it.
///
@interface SCIYTPlayer : UIViewController

/// Opens the list at one of its rows. The whole list is the queue, so next and previous
/// mean what they say.
+ (void)presentFrom:(UIViewController *)presenter
               jobs:(NSArray<SCIYTJob *> *)jobs
              start:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
