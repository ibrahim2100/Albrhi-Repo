//
//  SCIYTSettingsRegistry.h
//  Albrhi for YouTube
//
//  Features declare their own settings instead of being listed centrally.
//
//  The settings screen built every section itself, in one method, and that method was two
//  hundred lines and growing by one section per feature. Every new feature meant editing the
//  same file, which is where merge conflicts come from and, worse, where a feature that was
//  deleted leaves its rows behind because nobody remembered they were there.
//
//  A page registers in +load and owns its own file. Delete the file and the page is gone --
//  no other file mentions it. This mirrors what the Instagram side of this repository has
//  done since 3.x, deliberately: the two tweaks should be the same project to read.
//
//  **A page is now a screen of its own.** It began as a heading on one long scroll, which
//  worked while there were four of them and stopped working at nine: everything was on one
//  page, so nothing was findable, and the answer to "where is that setting" was to scroll
//  and hope. The registration carries a name and an icon now, the first screen is a list of
//  those names, and each opens its own. Nothing about how a page builds its rows changed --
//  only where they are shown.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTSettingRow.h"

NS_ASSUME_NONNULL_BEGIN

/// What a page may ask of the screen it is on.
///
/// A protocol rather than a bare UIViewController and -performSelector:. A selector no
/// translation unit declares is a compile error under -Werror, and reaching for one by name
/// gives up the only check there is that the method exists at all.
@protocol SCIYTSettingsHost <NSObject>
/// Rebuilds every section and redraws. For a page whose row shows a value it just changed.
- (void)reloadSettings;
@end

typedef UIViewController<SCIYTSettingsHost> SCIYTSettingsHostController;

/// Builds one page's sections.
///
/// Handed the screen they will appear on, because a disclosure row that opens a picker has
/// to present it from somewhere, and a page reaching for the key window instead would find
/// whatever YouTube happened to have on top.
///
/// Evaluated every time the screen is shown, so a row showing a chosen value shows the
/// current one rather than the one that was current at launch.
typedef NSArray<SCISection *> * _Nonnull (^SCIYTSectionsBuilder)(SCIYTSettingsHostController *host);


/// One registered page: what it is called on the first screen, and what it puts on its own.
@interface SCIYTPage : NSObject
@property (nonatomic, assign) NSInteger order;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, copy, nullable) NSString *symbol;
@property (nonatomic, copy) SCIYTSectionsBuilder builder;

/// This page's sections, built for a given screen.
///
/// The guard lives here rather than in the caller: the settings screen has been the crash
/// site twice in this project's history, and both times one page that could not build itself
/// took every other page with it. A page that throws costs its own rows and nothing else.
- (NSArray<SCISection *> *)sectionsFor:(SCIYTSettingsHostController *)host;
@end


@interface SCIYTSettingsRegistry : NSObject

/// Adds a page to the settings screen.
///
/// @param order Ascending, and gaps are deliberate: pages are registered in whatever order
///        +load happens to run them, which is not defined, so the number is the only thing
///        that decides what appears above what.
+ (void)registerPageWithOrder:(NSInteger)order
                        title:(NSString *)title
                       detail:(nullable NSString *)detail
                       symbol:(nullable NSString *)symbol
                      builder:(SCIYTSectionsBuilder)builder;

/// Every registered page, in order.
+ (NSArray<SCIYTPage *> *)pages;

@end

NS_ASSUME_NONNULL_END
