//
//  SCILKGesture.h
//  Albrhi for Locket
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

/// Hooks `-makeKeyAndVisible` so every window Locket makes gets a two-finger hold that
/// opens the status screen. Called once, from the constructor.
void SCILKInstallGesture(void);
