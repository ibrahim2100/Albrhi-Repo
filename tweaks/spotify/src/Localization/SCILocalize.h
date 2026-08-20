//
//  SCILocalize.h
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// This tweak's version, matched against `control` by tools/check.py.
extern NSString *SCIVersionString;

/// One user-facing string, in whichever of the two languages the phone is set to.
NSString *SCILocalized(NSString *key);

/// Helpers the ported SponsorBlock calls by their upstream names, so those files stay diffable.
NSString *EeveeJBRootPath(NSString *path);
void EeveeSBInvokeSeekDouble(id target, SEL selector, double argument);
