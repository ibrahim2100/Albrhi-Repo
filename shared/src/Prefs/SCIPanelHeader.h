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
+ (nullable UIView *)viewForWidth:(CGFloat)width
                           version:(NSString *)version
                                on:(NSInteger)on
                                of:(NSInteger)total;

/// The same header, for one tweak's own page.
///
/// **A page reached from a list needs to say what it is the page *for*.** The root header carries
/// Albrhi's mark because the root is Albrhi; a tweak's page carried nothing but a title bar, so a
/// page of nine switches opened looking like a fragment of Settings rather than part of this
/// project. The mark is drawn from an SF Symbol on an accent disc -- the same pair the tweaks use
/// in their own screens -- and the pill states the one thing the switches below cannot say at a
/// glance: whether the tweak is doing anything at all.
+ (UIView *)pageHeaderForWidth:(CGFloat)width
                        symbol:(NSString *)symbolName
                          tint:(UIColor *)tint
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                         state:(NSString *)state
                            on:(BOOL)on;

@end

NS_ASSUME_NONNULL_END
