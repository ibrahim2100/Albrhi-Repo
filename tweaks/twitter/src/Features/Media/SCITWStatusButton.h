//
//  SCITWStatusButton.h
//  Albrhi for Twitter
//
//  A save button on the tweet, on the classes a working tweak actually hooks.
//
//  Added beside the inline-media button rather than instead of it, and the report says
//  which of the two attached. The inline one hooks T1InlineMediaView -- a class that does
//  not appear anywhere in TWIGalaxy's binary, which is the evidence this file was written
//  from -- so it may well be attaching to nothing on this build of X. Until a device says
//  so, both are installed and neither is trusted.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCITWMedia.h"

NS_ASSUME_NONNULL_BEGIN

/// Hooks whichever of X's status views this build has. Safe when it has none.
void SCITWInstallStatusButton(void);

/// Which classes attached, how many tweets held media, how many buttons were added, and
/// how many of those actually landed on the video itself versus the tweet's own view as a
/// fallback -- read from the live hierarchy at the moment each button was shown, not
/// asserted from what the code intends.
NSString *SCITWStatusButtonReport(void);

/// The first saveable media on the tweet a view is showing, or nil.
///
/// Exposed because the tap handler and the injection both need it and they are in the same
/// file only by accident of size -- and because it is the one function here worth reusing if
/// a third surface is ever added.
SCITWMediaItem *_Nullable SCITWFirstSaveableInStatusView(UIView *view);

/// Finds the video inside `view` and places the save button on it, one turn of the runloop
/// later, searching upward from `view` for what to save.
///
/// **Both the search for the video and the search for what to save are deferred together,
/// and that is the fix over the version that took a pre-resolved host.** `didMoveToWindow`
/// runs before layout, so at the moment it fires the video view is often still zero by
/// zero -- `SCITWMediaSubview` rejects anything under 120 points, finds nothing, and a host
/// resolved *then* falls back to `view` itself, landing the button on the tweet's corner
/// instead of inside the picture. Resolving the host inside the dispatched block, after
/// layout has run, is what makes the button land in the video and stay there -- the same
/// placement Instagram's reel download button uses, on the frame itself rather than bolted
/// to the post around it.
///
/// The view is held weakly because a cell can be recycled or released in between, and a
/// strong capture would keep it alive to be decorated for no one.
void SCITWAddSaveButtonSoon(UIView *view);

NS_ASSUME_NONNULL_END
