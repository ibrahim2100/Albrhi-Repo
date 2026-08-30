//
//  SCIYTMDownloadsController.h
//  Albrhi for YouTube Music
//
//  The saved tracks, on a screen of their own.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

//
//  **A plain controller with a table inside it, not a `UITableViewController`.**
//
//  Five attempts at one symptom -- the first row sitting under the status bar -- were all spent on
//  `contentInset`, because a `UITableViewController`'s view *is* its table and there is nothing
//  else to move. Each fix was correct and each was undone by something else: the parent handing out
//  a zero safe area, an offset that keeps its value when an inset changes, a nil window on the
//  first layout pass, a `-reloadData` putting the offset back. A table whose *frame* starts below
//  the safe area cannot be undone by any of them.
//
@interface SCIYTMDownloadsController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@end
