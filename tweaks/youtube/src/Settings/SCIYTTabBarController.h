//
//  SCIYTTabBarController.h
//  Albrhi for YouTube
//
//  The screen that arranges the tab bar: drag to reorder, drag across to switch a tab off.
//
//  Two sections rather than a switch per row, because the two questions are one question.
//  A row's section says whether it is on, its position says where it goes, and moving it is
//  the only gesture -- so there is no way to express "hidden and third", which a switch beside
//  a draggable row would allow and then have to explain away.
//
//  The list is built from what the bar has actually handed the tweak, never from a table of
//  identifiers copied out of another tweak. Before the bar has been built once there is
//  nothing to show, and the screen says exactly that instead of drawing an empty list.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCIYTTabBarController : UITableViewController

/// Presents the screen over whatever is on top, wrapped in its own navigation controller.
+ (void)present;

@end
