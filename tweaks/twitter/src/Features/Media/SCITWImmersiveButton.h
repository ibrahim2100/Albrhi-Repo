//
//  SCITWImmersiveButton.h
//  Albrhi for Twitter
//
//  The save button inside the video, done the way the working tweak does it.
//
//  Reading TWIGalaxy's binary settled a question four releases had guessed at. It does not
//  put a floating button on an inline media view -- the class the other surface hooks,
//  `T1InlineMediaView`, does not appear anywhere in TWIGalaxy at all. What it hooks for the
//  in-video button is one Swift class: `ImmersiveInlinePlaybackButtonsStackView`, the row of
//  playback controls in X's immersive video player -- the full-screen, swipe-up video feed
//  that is X's answer to reels. It adds its download button *into that stack*, so the stack
//  lays it out beside like, reply and share on its own, with no frame math and nothing to
//  fight.
//
//  That is why the floating button "never appeared inside the video": it was the wrong
//  mechanism on a class that is not there. This is the right one -- an arranged subview of a
//  view that is, by construction, inside the picture.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks the immersive player's button stack, if this build has it. Safe when it does not.
void SCITWInstallImmersiveButton(void);

/// Whether the stack class was found, and how many buttons went into it. For the report,
/// so "no button in the video" can be told apart from "the class is not in this build".
NSString *SCITWImmersiveButtonReport(void);

/// The separate, pinned-inside-the-video button on ImmersiveVideoPageView. A separate
/// answer because it is a separate surface: the rail can be absent while this is present.
NSString *SCITWInVideoButtonReport(void);
