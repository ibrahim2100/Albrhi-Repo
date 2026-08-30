//
//  SCITWSectionRegistry.h
//  Albrhi for X
//
//  Sections register themselves; the screen only draws what it is handed.
//
//  One file per section, registering in `+load`, so adding a feature means adding a file
//  and nothing else — no shared list to edit, no merge conflict where two features touch
//  the same array, and deleting the file deletes the section. The Instagram tweak has been
//  built this way for a long time and it is the one part of its settings that has never
//  needed a fix.
//
//  A builder returning an empty array is simply not shown, which is how a section for a
//  class this build does not carry disappears rather than sitting there doing nothing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCITWRow.h"

NS_ASSUME_NONNULL_BEGIN

/// The host is the settings screen itself, handed over so a section can push a screen or
/// present a sheet without any of them holding a reference to the controller's class.
typedef NSArray<SCITWSection *> * _Nonnull (^SCITWSectionBuilder)(UIViewController *host);

@interface SCITWSectionRegistry : NSObject

/// `order` decides where the section sits. Left in tens so a new one can be slotted between
/// two others without renumbering anything.
+ (void)registerBuilderWithOrder:(NSInteger)order builder:(SCITWSectionBuilder)builder;

/// Every registered section, built fresh and in order, with the empty ones dropped.
+ (NSArray<SCITWSection *> *)sectionsForHost:(UIViewController *)host;

@end

NS_ASSUME_NONNULL_END
