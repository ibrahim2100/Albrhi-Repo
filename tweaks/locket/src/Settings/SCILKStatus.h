//
//  SCILKStatus.h
//  Albrhi for Locket
//
//  A small screen that says whether the bypass is working, opened by a two-finger hold.
//
//  Locket gives no sign either way — a jailbreak check it never sees the result of is
//  invisible. So the one thing a person needs is confirmation that the checks are being
//  answered, and a count that climbs proves it. Reached by a gesture on Locket's own window
//  rather than a row in its settings, because Locket is a Flutter app with no settings
//  screen this could hook.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCILKStatus : UITableViewController
/// Puts the screen on top of whatever Locket is showing. Does nothing when it is already up.
+ (void)present;
@end
