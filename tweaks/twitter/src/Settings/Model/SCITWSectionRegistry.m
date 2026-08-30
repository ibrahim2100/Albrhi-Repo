#import "SCITWSectionRegistry.h"

@interface SCITWRegisteredSection : NSObject
@property (nonatomic, assign) NSInteger order;
@property (nonatomic, copy) SCITWSectionBuilder builder;
@end

@implementation SCITWRegisteredSection
@end


@implementation SCITWSectionRegistry

static NSMutableArray<SCITWRegisteredSection *> *sciRegistered = nil;

+ (void)registerBuilderWithOrder:(NSInteger)order builder:(SCITWSectionBuilder)builder {
    if (!builder) return;
    if (!sciRegistered) sciRegistered = [NSMutableArray array];

    SCITWRegisteredSection *entry = [[SCITWRegisteredSection alloc] init];
    entry.order = order;
    entry.builder = builder;
    [sciRegistered addObject:entry];
}

+ (NSArray<SCITWSection *> *)sectionsForHost:(UIViewController *)host {
    // Sorted here rather than on insert, because `+load` order across files is not
    // something a reader of any one of them could predict -- and a screen whose section
    // order depends on link order is a screen that reorders itself between builds.
    NSArray<SCITWRegisteredSection *> *sorted =
        [sciRegistered sortedArrayUsingComparator:^NSComparisonResult(SCITWRegisteredSection *a,
                                                                     SCITWRegisteredSection *b) {
            if (a.order == b.order) return NSOrderedSame;
            return a.order < b.order ? NSOrderedAscending : NSOrderedDescending;
        }];

    NSMutableArray<SCITWSection *> *built = [NSMutableArray array];
    for (SCITWRegisteredSection *entry in sorted) {
        NSArray<SCITWSection *> *sections = entry.builder(host);
        for (SCITWSection *section in sections) {
            if (section.rows.count) [built addObject:section];
        }
    }
    return built;
}

@end
