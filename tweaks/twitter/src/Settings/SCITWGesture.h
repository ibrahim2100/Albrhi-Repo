//
//  SCITWGesture.h
//  Albrhi for Twitter
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

/// Puts the two-finger hold on one window, once. Safe to call again for the same window.
void SCITWAttachGesture(UIWindow *window);

/// Hooks `-makeKeyAndVisible` so every window X makes from here on gets the gesture.
/// Called once, from the constructor.
void SCITWInstallGesture(void);
