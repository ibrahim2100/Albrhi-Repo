#import "SCIYTSettingsRegistry.h"

/// Registrations, kept in the order they must appear rather than the order they arrived.
static NSMutableArray<SCIYTPage *> *sciPages = nil;

@implementation SCIYTPage

- (NSArray<SCISection *> *)sectionsFor:(SCIYTSettingsHostController *)host {
    if (!self.builder) return @[];

    NSMutableArray<SCISection *> *sections = [NSMutableArray array];

    @try {
        for (SCISection *section in self.builder(host)) {
            // An empty section is a feature that decided it has nothing to offer on this
            // build. Dropped rather than drawn as a heading over nothing.
            if (section.rows.count) [sections addObject:section];
        }
    } @catch (__unused NSException *exception) { }

    return sections;
}

@end


@implementation SCIYTSettingsRegistry

+ (void)registerPageWithOrder:(NSInteger)order
                        title:(NSString *)title
                       detail:(NSString *)detail
                       symbol:(NSString *)symbol
                      builder:(SCIYTSectionsBuilder)builder {
    if (!builder || !title.length) return;

    // +load ordering is undefined, so this can run before any +initialize would have. Built
    // here rather than relying on one.
    if (!sciPages) sciPages = [NSMutableArray array];

    SCIYTPage *page = [[SCIYTPage alloc] init];
    page.order = order;
    page.title = title;
    page.detail = detail;
    page.symbol = symbol;
    page.builder = builder;

    [sciPages addObject:page];
}

+ (NSArray<SCIYTPage *> *)pages {
    if (!sciPages) return @[];

    return [sciPages sortedArrayUsingComparator:^NSComparisonResult(SCIYTPage *a, SCIYTPage *b) {
        if (a.order == b.order) return NSOrderedSame;
        return (a.order < b.order) ? NSOrderedAscending : NSOrderedDescending;
    }];
}

@end
