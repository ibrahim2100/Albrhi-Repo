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

/// Which classes attached, how many tweets held media, how many buttons were added.
NSString *SCITWStatusButtonReport(void);

/// The first saveable media on the tweet a view is showing, or nil.
///
/// Exposed because the tap handler and the injection both need it and they are in the same
/// file only by accident of size -- and because it is the one function here worth reusing if
/// a third surface is ever added.
SCITWMediaItem *_Nullable SCITWFirstSaveableInStatusView(UIView *view);

/// Places the save button on `host`, searching upward from `view` for what to save.
///
/// Two arguments because they are two different things: `T1InlineMediaView` is the video and
/// is where the button belongs, and its own view model answers nothing -- the device report
/// settled that with "25 models, 0 with media". The tweet's model, further up, is the one
/// that knows.
///
/// Deferred by one turn of the runloop. `didMoveToWindow` runs before layout, so the view is
/// often still zero by zero when it fires, and a button placed then lands in the wrong
/// corner or nowhere. One turn later is after layout and still outside it, so nothing is
/// invalidated and none of the recursion the constraint version caused is possible.
void SCITWAddSaveButtonSoon(UIView *host, UIView *view);

NS_ASSUME_NONNULL_END
