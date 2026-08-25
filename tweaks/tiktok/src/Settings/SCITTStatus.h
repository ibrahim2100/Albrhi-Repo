//
//  SCITTStatus.h
//  Albrhi for TikTok
//
//  The settings screen.
//
//  **Rebuilt from nothing in 0.20.0.** What was here was a grouped table with a header view, a
//  footer view and forty rows under seven titles -- correct, and shaped like a form from 2013. The
//  screen is a collection view now with a layout per section: an identity card, a grid of
//  categories, and a page of option cards behind each one.
//
//  The class name and `+present` are unchanged on purpose. The long-press gesture, the welcome
//  screen and the report all call this, and a rename would have been a fourth thing to edit for a
//  change none of them care about.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCITTStatus : UIViewController

/// Shows the settings, wrapped in a navigation controller, over whatever is on screen.
+ (void)present;

@end
