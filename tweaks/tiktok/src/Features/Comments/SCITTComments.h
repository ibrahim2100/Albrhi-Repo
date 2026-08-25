//
//  SCITTComments.h
//  Albrhi for TikTok
//
//  Two things a long press on a comment should be able to do.
//
//  **Both live on one class, and it was found by asking the binary rather than a reference tweak.**
//  `TTKCommentAppReviewsLongPressHelper` owns `-buildActionSheetForModel:index:` (`@32@0:8@16@24`),
//  `-copyCommentContent:` (`v24@0:8@16`) and `-addCopyActionToSheet:content:` -- the whole
//  long-press menu for a comment. Forty `AWE*Comment*` classes were searched first and none had it;
//  the name lives under `TTK`, which is where TikTok has been moving things.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Adds *Save media* to a comment's own long-press sheet, and cleans the username out of what
/// *Copy* puts on the pasteboard. Each half installs only if its selector's encoding matches.
void SCITTInstallComments(void);

NS_ASSUME_NONNULL_END
