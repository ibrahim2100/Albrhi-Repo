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
