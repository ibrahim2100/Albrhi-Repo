//
//  SCILKQuickSave.h
//  Albrhi for Locket
//
//  A one-tap shortcut to the newest moment, since the moment-viewing screen itself is
//  SwiftUI and answers no Objective-C question about which moment is on screen -- see
//  SCILKMedia.h for why the button asked for could not be placed there. This is placed
//  on the window instead, the same way the two-finger gesture already is, and saves
//  whatever was captured most recently rather than whatever happens to be visible.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Attaches the button to every window Locket makes key, the same way SCILKInstallGesture
/// does. Safe to call unconditionally.
void SCILKInstallQuickSave(void);
