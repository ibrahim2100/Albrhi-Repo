#import "SCISettingsRegistry.h"
#import "SCISymbol.h"
#import "../Utils.h"

/// Where the feature list sits among the root sections.
static const NSInteger SCISettingsFeatureListOrder = 300;

@implementation SCISettingsRegistry

// Each entry: @{ @"order": NSNumber, @"builder": block, ... }
static NSMutableArray<NSDictionary *> *_rootSections = nil;
static NSMutableArray<NSDictionary *> *_featurePages = nil;

+ (void)initialize {
    if (self != [SCISettingsRegistry class]) return;

    _rootSections = [NSMutableArray array];
    _featurePages = [NSMutableArray array];
}

// MARK: - Registration

+ (void)registerFeaturePageWithTitle:(NSString *(^)(void))titleBuilder
                                icon:(NSString *)symbolName
                               order:(NSInteger)order
                            sections:(SCISectionsBuilder)sectionsBuilder {
    if (!titleBuilder || !sectionsBuilder) return;

    [_featurePages addObject:@{
        @"order": @(order),
        @"title": [titleBuilder copy],
        @"icon": symbolName ?: @"square.grid.2x2",
        @"sections": [sectionsBuilder copy]
    }];
}

+ (void)registerRootSectionWithOrder:(NSInteger)order
                             builder:(NSArray *(^)(void))sectionBuilder {
    if (!sectionBuilder) return;

    [_rootSections addObject:@{
        @"order": @(order),
        @"builder": [sectionBuilder copy]
    }];
}

// MARK: - Composition

+ (NSArray<NSDictionary *> *)sortedByOrder:(NSArray<NSDictionary *> *)entries {
    return [entries sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"order"] compare:b[@"order"]];
    }];
}

+ (NSArray<SCISetting *> *)featurePageRows {
    NSMutableArray<SCISetting *> *rows = [NSMutableArray array];

    for (NSDictionary *page in [self sortedByOrder:_featurePages]) {
        NSString *(^titleBuilder)(void) = page[@"title"];
        SCISectionsBuilder sectionsBuilder = page[@"sections"];

        NSArray *sections = sectionsBuilder();
        // A feature that resolves to nothing (unsupported IG build, disabled flag)
        // simply doesn't appear — no placeholder row, no crash.
        if (!sections.count) continue;

        [rows addObject:[SCISetting navigationCellWithTitle:titleBuilder()
                                                   subtitle:@""
                                                       icon:[SCISymbol symbolWithName:page[@"icon"]]
                                                navSections:sections]];
    }

    return rows;
}

+ (NSArray *)composedSections {
    NSMutableArray *out = [NSMutableArray array];

    BOOL featureListInserted = NO;

    for (NSDictionary *entry in [self sortedByOrder:_rootSections]) {
        // Splice the feature list in at its reserved position.
        if (!featureListInserted && [entry[@"order"] integerValue] > SCISettingsFeatureListOrder) {
            [out addObjectsFromArray:[self featureListSections]];
            featureListInserted = YES;
        }

        NSArray *(^builder)(void) = entry[@"builder"];
        NSArray *section = builder();
        if (section.count) [out addObjectsFromArray:section];
    }

    if (!featureListInserted) {
        [out addObjectsFromArray:[self featureListSections]];
    }

    return [out copy];
}

+ (NSArray *)featureListSections {
    NSArray<SCISetting *> *rows = [self featurePageRows];
    if (!rows.count) return @[];

    return @[@{
        @"header": @"",
        @"rows": rows
    }];
}

@end
