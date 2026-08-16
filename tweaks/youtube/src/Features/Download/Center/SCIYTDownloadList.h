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
/// One third of the Download Centre: everything of a single section.
///
/// Three lists rather than one with a filter, because they are not the same thing to
/// look at. A saved video wants its own still beside it and the row has to be tall
/// enough to show one; a Short wants that same still in the tall shape it actually is,
/// not squeezed into a landscape frame it never had; a saved song wants a compact row
/// and never has a picture. Putting all three in one table means every row is sized and
/// shaped for whichever of them needs the most room.
///
/// The list is also the queue. Opening a row hands the whole list to the player, in the
/// order shown, so next and previous move through what is on the screen rather than
/// through some other order the player invented.
///
@interface SCIYTDownloadList : UITableViewController

/// A list of one kind. Downloads still running appear in whichever list they will join.
///
/// `shorts` only means anything for `SCIYTJobKindVideo`: NO is ordinary video and
/// excludes anything saved from Shorts, YES is Shorts and excludes everything else.
/// Audio has no such split -- a Short saved as sound alone plays back exactly like any
/// other saved sound, so there is nothing about it worth a fourth list.
- (instancetype)initWithKind:(SCIYTJobKind)kind shorts:(BOOL)shorts;

/// Closes the Centre. UIKit forwards this up to whatever presented it, so a list asking
/// to be dismissed takes the whole sheet with it.
- (void)close;

@end

NS_ASSUME_NONNULL_END
