//
//  SCIYTMiniPlayer.h
//  Albrhi for YouTube
//
//  The strip along the bottom of the Centre, showing what is playing.
//
//  This is what makes the difference between a player and a file opener: sound carries on
//  while you look at the rest of your downloads, and tapping the strip puts the full screen
//  back exactly where it was. It exists because the player is now one long-lived object
//  rather than one built per tap -- closing the screen stopped the music before, which meant
//  the list could only ever be looked at in silence.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTMiniPlayer : UIView

/// Told when the bar appears or goes away, so the page can give the list back the room.
@property (nonatomic, copy, nullable) void (^miniPlayerVisibilityChanged)(BOOL visible);

@end

NS_ASSUME_NONNULL_END
