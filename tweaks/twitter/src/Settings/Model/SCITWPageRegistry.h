//
//  SCITWPageRegistry.h
//  Albrhi for X
//
//  Pages register themselves; the first screen is a list of them.
//
//  **One screen of nine sections became a screen of nine rows.** Everything this tweak can
//  do used to be one long table -- the save button, the link cleaner, the timeline filters,
//  the feature list, the diagnostics -- and finding any of it meant scrolling past all of
//  it. This is the shape the YouTube tweak has used since it grew past two hundred lines of
//  section building: a root list of categories, each pushing to its own screen, each screen
//  built by its own file.
//
//  A page whose builder returns no sections is not listed at all, which is how a page for a
//  class this build does not carry disappears rather than opening onto nothing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCITWRow.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSArray<SCITWSection *> * _Nonnull (^SCITWPageBuilder)(UIViewController *host);

/// One page: how it is listed, and what it contains.
@interface SCITWPage : NSObject
@property (nonatomic, assign) NSInteger order;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *note;
@property (nonatomic, copy, nullable) NSString *symbol;
@property (nonatomic, strong, nullable) UIColor *tint;
@property (nonatomic, copy) SCITWPageBuilder builder;
@end


@interface SCITWPageRegistry : NSObject

/// `order` decides where the page sits in the list. Left in tens so a new one can be
/// slotted between two others without renumbering anything.
+ (void)registerPageWithOrder:(NSInteger)order
                        title:(NSString *)title
                         note:(nullable NSString *)note
                       symbol:(nullable NSString *)symbol
                         tint:(nullable UIColor *)tint
                      builder:(SCITWPageBuilder)builder;

/// Every registered page, in order.
+ (NSArray<SCITWPage *> *)pages;

/// The sections a page contains, built fresh, with the empty ones dropped. Built on the way
/// in rather than kept, so an info row reads its value at the moment the screen is drawn.
+ (NSArray<SCITWSection *> *)sectionsForPage:(SCITWPage *)page host:(UIViewController *)host;

@end

NS_ASSUME_NONNULL_END
