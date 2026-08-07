//
//  SCIPanelHeader.h
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The mark, the name and the version, above the list.
///
/// A settings page with no header is a list of switches belonging to nothing. This one
/// belongs to a project with a name and a logo, and the page is where most people will
/// meet both — they arrive here from Settings, not from a package manager.
///
/// **Built as a table header view, measured once.** Not a `PSGroupCell` with a custom
/// class, and not a view pinned above the table: a header sized by
/// `systemLayoutSizeFittingSize:` has no constraint relating it to anything outside
/// itself, which is the arrangement three rebuilds of the Instagram panel arrived at
/// after two of them died inside CoreAutoLayout.
///
@interface SCIPanelHeader : NSObject

/// A header sized for this width. Nil only if the artwork is missing, in which case the
/// page shows its list with no header rather than not showing.
+ (nullable UIView *)viewForWidth:(CGFloat)width version:(NSString *)version;

@end

NS_ASSUME_NONNULL_END
