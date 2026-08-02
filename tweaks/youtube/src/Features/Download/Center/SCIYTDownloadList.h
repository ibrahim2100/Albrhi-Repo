//
//  SCIYTDownloadList.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTJob.h"

NS_ASSUME_NONNULL_BEGIN

///
/// One half of the Download Centre: everything of a single kind.
///
/// Two lists rather than one with a filter, because they are not the same thing to look
/// at. A saved video wants its own still beside it and the row has to be tall enough to
/// show one; a saved song wants a compact row and never has a picture. Putting both in
/// one table means every row is sized for the taller of the two.
///
/// The list is also the queue. Opening a row hands the whole list to the player, in the
/// order shown, so next and previous move through what is on the screen rather than
/// through some other order the player invented.
///
@interface SCIYTDownloadList : UITableViewController

/// A list of one kind. Downloads still running appear in whichever list they will join.
- (instancetype)initWithKind:(SCIYTJobKind)kind;

/// Closes the Centre. UIKit forwards this up to whatever presented it, so a list asking
/// to be dismissed takes the whole sheet with it.
- (void)close;

@end

NS_ASSUME_NONNULL_END
