//
//  SCIPanelAppCell.h
//  Albrhi Panel
//
//  One row per patched app, carrying everything that used to take two sections.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Preferences/PSSwitchTableCell.h>

NS_ASSUME_NONNULL_BEGIN

///
/// A switch row with a subtitle, for the apps list.
///
/// `PSSwitchCell` gives a title and a switch and nothing else, so everything a row could
/// usefully say about an app — which version is on the phone, which one the tweak was
/// verified against, whether the app is even installed — had to live in a second section
/// that listed the same apps again. Two passes down the same list to answer one question
/// about one app.
///
/// This subclasses `PSSwitchTableCell`, which Theos ships a header for, so the switch, its
/// target/action wiring and the enabled state all keep working exactly as the plain cell's
/// did. What is added is a second line and a larger, rounded icon. **No private property is
/// guessed at**: `-specifier` and `-refreshCellContentsWithSpecifier:` are both declared in
/// `PSTableCell.h`, which is the same header this bundle already builds against.
///
@interface SCIPanelAppCell : PSSwitchTableCell
@end

NS_ASSUME_NONNULL_END
