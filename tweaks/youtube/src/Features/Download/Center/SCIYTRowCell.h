//
//  SCIYTRowCell.h
//  Albrhi for YouTube
//
//  One row in the Download Centre, drawn rather than configured.
//
//  What this replaces was UITableViewCellStyleSubtitle with its imageView and two labels, and
//  that was the ceiling on how this screen could look: a stock cell puts the picture in a
//  fixed square, will not overlay anything on it, and gives the title and subtitle a spacing
//  decided in 2010. Every list in the app it sits beside stopped using those years ago.
//
//  **One cell for both kinds, not two classes.** A saved video and a saved song differ in the
//  shape of their artwork and in one badge; everything else -- the title, the meta line, the
//  progress, the playing mark -- is identical, and two classes would be two places to change
//  the same thing. The shape is a constraint that gets swapped, which is the actual
//  difference expressed as the actual difference.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTJob.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTRowCell : UITableViewCell

/// The height a row of this kind wants. Asked by the table rather than guessed at.
+ (CGFloat)heightForKind:(SCIYTJobKind)kind;

/// Fills the row in. Everything the cell shows comes from here and nothing is left over
/// from the row this cell was last used for.
- (void)fillWith:(SCIYTJob *)job
         artwork:(nullable UIImage *)artwork
         playing:(BOOL)playing;

@end

NS_ASSUME_NONNULL_END
