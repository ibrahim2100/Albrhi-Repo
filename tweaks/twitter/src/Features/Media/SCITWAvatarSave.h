//
//  SCITWAvatarSave.h
//  Albrhi for Twitter
//
//  Saving a profile photo, from the same gesture that already opens it full screen.
//
//  Reached through `T1ProfileHeaderViewController`'s own `-summaryView:didTapAvatar:
//  menuSource:fromLongPress:` -- the exact delegate call the profile header makes when its
//  avatar is tapped, whether that opens the photo full screen or something else. The photo
//  itself comes from `-[TFNTwitterUser profileImageMediaEntity]`, which is a
//  `TFSTwitterEntityMedia` -- the same class `SCITWMedia itemForEntity:` already knows how
//  to resolve into a saveable item, so this feature adds no new media-handling code at all.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks the profile header's avatar-tap delegate call, if this build has it.
void SCITWInstallAvatarSave(void);

NSString *SCITWAvatarSaveReport(void);
