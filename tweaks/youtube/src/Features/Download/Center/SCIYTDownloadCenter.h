//
//  SCIYTDownloadCenter.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The Download Centre.
///
/// Everything that has been saved, and everything still being saved, in one list — and
/// tapping one plays it here rather than sending it anywhere. That is the point of it:
/// a downloaded video used to leave for Photos immediately and there was no such thing
/// as "my downloads" at all.
///
/// A UITableViewController for the reason the settings panel is one. Three releases were
/// spent on a panel of hand-written constraints that either failed to appear or died in
/// CoreAutoLayout, and the fix was to stop writing constraints between siblings.
///
@interface SCIYTDownloadCenter : UITableViewController

/// Opens it over whatever is on screen. Guarded; a screen that cannot be built must
/// fail to open rather than take YouTube with it.
+ (void)present;

@end

NS_ASSUME_NONNULL_END
