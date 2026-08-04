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
//  A page registers in +load and owns its own file. Delete the file and the section is gone
//  -- no other file mentions it. This mirrors what the Instagram side of this repository has
//  done since 3.x, deliberately: the two tweaks should be the same project to read.
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

@interface SCIYTSettingsRegistry : NSObject

/// Adds sections to the settings screen.
///
/// @param order Ascending, and gaps are deliberate: pages are registered in whatever order
///        +load happens to run them, which is not defined, so the number is the only thing
///        that decides what appears above what.
+ (void)registerSectionsWithOrder:(NSInteger)order builder:(SCIYTSectionsBuilder)builder;

/// Every registered page's sections, in order.
+ (NSArray<SCISection *> *)composedSectionsFor:(SCIYTSettingsHostController *)host;

@end

NS_ASSUME_NONNULL_END
