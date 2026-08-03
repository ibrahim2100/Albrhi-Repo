//
//  SCIYTCentrePage.h
//  Albrhi for YouTube
//
//  The Download Centre as a page, not as a window over the app.
//
//  It used to be presented modally: the whole screen slid up over YouTube, covering the tab
//  bar, and it read as something bolted on -- because that is exactly what a modal is. A
//  page reached from the tab bar should behave like Home and You do. The bar stays, the tab
//  stays lit, and the content underneath changes.
//
//  So the two lists live in one page with a segmented header rather than in a tab bar of
//  their own. A UITabBarController embedded here would put its own tab bar directly above
//  YouTube's, which is the same mistake at a smaller size.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCIYTCentrePage : UIViewController

/// Whether a Done button appears.
///
/// Yes when opened from settings, where it is presented and has to be dismissible. No when
/// it is the tab bar's page, where there is nothing to dismiss -- you leave by tapping
/// another tab, and a Done button there would be a door in the middle of a room.
- (instancetype)initWithDismissButton:(BOOL)dismissable;

@end
