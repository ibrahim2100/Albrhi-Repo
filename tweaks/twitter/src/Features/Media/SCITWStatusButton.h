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

NS_ASSUME_NONNULL_END
