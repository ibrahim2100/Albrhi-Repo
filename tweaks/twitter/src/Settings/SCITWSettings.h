//
//  SCITWSettings.h
//  Albrhi for Twitter
//
//  This tweak's own screen, opened by holding two fingers anywhere in X.
//
//  Not a page inserted into X's own settings, and that is deliberate for this release.
//  Adding a row to another app's settings means hooking that app's settings screen, which
//  is a view -- the exact kind of hook this tweak exists to avoid depending on. A gesture
//  belongs to us and works in every screen of the app, including the ones that have no
//  settings.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCITWTable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCITWSettings : SCITWTable

/// Puts the screen on top of whatever X is showing.
///
/// Does nothing when it is already up: the gesture can fire twice from one hold, and a
/// second copy of this over the first is a screen with two Done buttons where only the
/// top one works.
+ (void)present;

@end

NS_ASSUME_NONNULL_END
