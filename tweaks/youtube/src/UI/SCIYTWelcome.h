//
//  SCIYTWelcome.h
//  Albrhi for YouTube
//
//  What the tweak says the first time it runs.
//
//  Three things and no more: where saved videos go, that they do not go to Photos on their
//  own, and how to reach the settings. A tweak that installs itself invisibly and then
//  waits to be discovered is a tweak whose features nobody uses.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCIYTWelcome : UIViewController

/// Shows it once, ever. Does nothing on later launches.
+ (void)showIfFirstRun;

@end
