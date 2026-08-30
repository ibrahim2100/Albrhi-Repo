//
//  SCIYTTabBar.h
//  Albrhi for YouTube
//
//  Which tabs the bar carries, and in what order.
//
//  YouTube builds its tab bar from a protobuf -- a `YTIPivotBarRenderer` holding one
//  `YTIPivotBarItemRenderer` per tab -- and hands it to the bar through `-setRenderer:`.
//  The Download Centre tab already rides that path by appending one item, so hiding and
//  reordering are the same path used twice: the array is rewritten before YouTube reads it.
//
//  **Every decision here is made on `pivotIdentifier`, never on position.** A tab's index
//  changes with the account, the page style and whatever YouTube is experimenting with this
//  week; its identifier does not. That also makes this hook and the Download Centre's hook
//  order-independent -- both mutate the same mutable array before `%orig`, and rearranging
//  by name gives the same answer whichever ran first, which is the only reason two hooks on
//  one method are safe to write in two files.
//
//  **The tab list is observed, not hard-coded.** A table of identifiers written from
//  reading somebody else's tweak is a table of guesses, and this project has paid for that
//  three times. So the bar reports every identifier it is handed, those are remembered, and
//  the settings screen offers exactly what this device has actually seen. A known list is
//  used only to give a name to an identifier already observed -- never to claim a tab
//  exists.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Every identifier this device's tab bar has been handed, in the order first seen.
/// Empty until the bar has been built once, which is why the settings screen says so
/// rather than drawing an empty list that reads as a broken screen.
NSArray<NSString *> *SCIYTTabBarSeenIdentifiers(void);

/// Records an identifier the bar was handed. Cheap and idempotent.
void SCIYTTabBarNoteIdentifier(NSString *identifier);

/// The item renderer inside one entry of the bar's items array, whichever kind it is.
///
/// **There are two, and reading only the first is why the create button could not be
/// switched off.** `YTIPivotBarSupportedRenderers` carries either a `pivotBarItemRenderer`
/// or a `pivotBarIconOnlyItemRenderer`, and the `+` in the middle of the bar is the second
/// kind — so every lookup that asked only for the first found nothing, and an entry with no
/// identifier is one this screen cannot list and this arranger will not move. Both carry
/// `pivotIdentifier`, so once the right one is read the create button is an ordinary row.
id SCIYTTabBarInnerRenderer(id entry);

/// An SF Symbol standing in for a tab, for the preview strip on the settings screen. Never
/// for the bar itself — YouTube draws that, and a symbol of ours there would be a guess at
/// its icon rather than a sketch of it.
NSString *SCIYTTabBarSymbolFor(NSString *identifier);

/// A human name for an identifier: YouTube's own tabs get their localized name, ours gets
/// the Download Centre's, and anything unrecognised is shown by its raw identifier rather
/// than hidden -- an unnamed tab is still a tab somebody may want to move.
NSString *SCIYTTabBarDisplayName(NSString *identifier);

/// The active tabs in display order, and the ones switched off. Both are stored as arrays
/// of identifiers so an order and a visibility are one decision, not two that can disagree.
NSArray<NSString *> *SCIYTTabBarActiveOrder(void);
NSArray<NSString *> *SCIYTTabBarHiddenIdentifiers(void);
void SCIYTTabBarSetActiveOrder(NSArray<NSString *> *active, NSArray<NSString *> *hidden);

/// Six, and it is a fact about `YTPivotBarView` rather than a policy of this tweak.
///
/// Measured, not inherited from the comment that used to assert it: the class declares
/// `itemView1` … `itemView6` as six separate properties, and `itemViews` is the array of
/// those. There is no seventh, so a seventh item renderer has nothing to be drawn in.
///
/// Going past it would mean building a tab view of our own, adding it to the bar's content
/// view and positioning it from `-layoutSubviews` — owning the layout, the selected state,
/// the page style and the scrub gesture. That is the floating-button approach this feature
/// was written to replace, and it is why the number is not a setting.
extern const NSUInteger SCIYTTabBarMaximum;

/// Whether a stored arrangement exists, and therefore whether `SCIYTTabBarArrange` is going
/// to rewrite the bar after the tabs of ours are appended.
///
/// **This is what decides whether an append may exceed six.** It matters because the
/// arrangement is what *removes* things: with one stored, appending a seventh is fine
/// because a hidden tab is about to be dropped and the list truncated; with none stored,
/// nothing will be removed and a seventh would simply have no view to be drawn in.
BOOL SCIYTTabBarWillArrange(void);

/// Rewrites `items` in place: drops what is switched off, orders the rest. Anything the
/// user has never seen keeps its place at the end rather than being dropped, so a tab
/// YouTube adds tomorrow appears instead of silently vanishing.
///
/// Refuses to leave the bar empty. A stored list that matches nothing would otherwise take
/// away every way of navigating the app, which is the same rule that keeps the download
/// button visible when a lookup fails.
void SCIYTTabBarArrange(NSMutableArray *items);

/// One line for the diagnostics page: what was seen, what was kept, what was dropped.
NSString *SCIYTTabBarReport(void);

NS_ASSUME_NONNULL_END
