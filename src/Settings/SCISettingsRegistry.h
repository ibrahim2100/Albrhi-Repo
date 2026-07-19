#import <Foundation/Foundation.h>
#import "SCISetting.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Settings registry
///
/// Features declare their own settings instead of being listed centrally, so a
/// feature can be added or removed by adding or deleting a single file. Nothing
/// else in the project needs to know it exists.
///
/// Registration happens in `+load`, which runs before the settings screen can be
/// opened. Order between `+load` calls is undefined, hence the explicit `order`.
///
/// Two shapes are supported:
///
///   * **Feature page** — a row in the main list that pushes its own sub-page.
///     This is what almost every feature wants.
///
///   * **Root section** — a standalone section on the top-level page. Reserved
///     for things that must be reachable immediately (language, accent, credits).
///
/// Builders are evaluated every time the screen is shown, so localized strings
/// and live values are always current.
///

typedef NSArray * _Nonnull (^SCISectionsBuilder)(void);

@interface SCISettingsRegistry : NSObject

/// Adds a navigation row to the main feature list.
/// @param order Ascending. Leave gaps so features can be inserted later.
+ (void)registerFeaturePageWithTitle:(NSString * _Nonnull (^)(void))titleBuilder
                                icon:(NSString *)symbolName
                               order:(NSInteger)order
                            sections:(SCISectionsBuilder)sectionsBuilder;

/// Adds a section directly to the top-level page.
+ (void)registerRootSectionWithOrder:(NSInteger)order
                             builder:(NSArray * _Nonnull (^)(void))sectionBuilder;

/// The composed top-level section array, ordered. Consumed by SCITweakSettings.
+ (NSArray *)composedSections;

/// Every registered feature page as navigation rows, ordered.
+ (NSArray<SCISetting *> *)featurePageRows;

@end

NS_ASSUME_NONNULL_END
