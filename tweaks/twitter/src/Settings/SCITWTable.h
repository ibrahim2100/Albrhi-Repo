//
//  SCITWTable.h
//  Albrhi for X
//
//  The one place a settings row is drawn.
//
//  Both screens are this class: the first one, which lists the pages, and every page it
//  pushes to. They differ only in what `-buildSections` returns -- which is the whole point
//  of splitting the pages into files in the first place. Drawing a switch in two places is
//  how one of them ends up with a font the other does not have.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "Model/SCITWRow.h"

NS_ASSUME_NONNULL_BEGIN

/// A rounded colour badge, the way Settings.app draws its own rows. Shared because the
/// page list and the pages both use it, at two sizes.
UIImage *SCITWBadgeOfSide(NSString *symbolName, UIColor *_Nullable color, CGFloat side);
UIImage *SCITWBadge(NSString *symbolName, UIColor *_Nullable color);

@interface SCITWTable : UITableViewController

/// What is drawn. Rebuilt by `-reload`, never edited in place.
@property (nonatomic, strong) NSArray<SCITWSection *> *sections;

/// Subclasses answer this. The base returns nothing, so a subclass that forgets shows an
/// empty screen rather than inheriting somebody else's rows.
- (NSArray<SCITWSection *> *)buildSections;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
