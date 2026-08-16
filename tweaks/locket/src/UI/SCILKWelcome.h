//
//  SCILKWelcome.h
//  Albrhi for Locket
//
//  What the tweak says the first time it runs.
//
//  Three things and no more: that moments hold two fingers away, that the jailbreak
//  check is answered rather than the app blocked, and that nothing about payment is
//  touched. A tweak that hides both what it does and how to reach it is a tweak nobody
//  finds out how to use.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCILKWelcome : UIViewController

/// Shows it once, ever. Does nothing on later launches.
+ (void)showIfFirstRun;

@end
