//
//  SCIYTHistoryTab.h
//  Albrhi for YouTube
//
//  A History tab in the bottom bar, opened by YouTube's own navigation.
//
//  The Download Centre tab handles its own tap, because there is no YouTube page behind it.
//  History is the opposite: the page already exists and is reached by a browse endpoint, so
//  this builds the tab and then gets out of the way — YouTube resolves `FEhistory` itself,
//  with its own loading, its own back behaviour and its own selection state.
//
//  **Every field below was read off a real YouTube binary, not guessed.**
//  `YTIPivotBarItemRenderer` declares `navigationEndpoint : YTICommand`; `YTICommand`
//  declares `browseEndpoint : YTIBrowseEndpoint` with a real `-setBrowseEndpoint:`; and
//  `YTIBrowseEndpoint` declares `browseId : NSString`. That chain is the whole feature, and
//  it is the third time in this repository a resolver has been built by walking declared
//  property *types* hop by hop rather than trusting a name that exists somewhere.
//
//  **The icon is still painted rather than set through the renderer**, for the reason the
//  Download Centre tab already records: a `YTIIcon` wants an `iconType` enum whose values
//  are not readable from the binary, and a guessed number draws the wrong picture or none.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// YouTube's own identifier for the watch history page. Used for both the pivot identifier
/// and the browse id, which is what YouTube's other tabs do.
extern NSString *const SCIYTHistoryPivot;

/// Whether the tab is switched on.
BOOL SCIYTHistoryTabWanted(void);

/// Whether an already-built renderer is the History one -- ours or, on a build that ships
/// it, YouTube's own. Both are the same tab and neither should be added twice.
BOOL SCIYTIsHistoryRenderer(id renderer);

/// Builds the tab, or nil if this build has no such classes or a field would not take.
/// The reason is recorded either way, so "no History tab" is never a silent nothing.
id _Nullable SCIYTMakeHistoryItem(void);

/// Puts the clock on the tab YouTube has drawn. Idempotent.
BOOL SCIYTPaintHistoryIcon(UIView *view);

/// One line for the diagnostics page.
NSString *SCIYTHistoryTabReport(void);

NS_ASSUME_NONNULL_END
