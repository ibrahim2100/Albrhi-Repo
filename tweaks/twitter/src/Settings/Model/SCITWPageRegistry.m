#import "SCITWPageRegistry.h"

@implementation SCITWPage
@end


@implementation SCITWPageRegistry

static NSMutableArray<SCITWPage *> *sciPages = nil;

+ (void)registerPageWithOrder:(NSInteger)order
                        title:(NSString *)title
                         note:(NSString *)note
                       symbol:(NSString *)symbol
                         tint:(UIColor *)tint
                      builder:(SCITWPageBuilder)builder {
    if (!builder || !title.length) return;
    if (!sciPages) sciPages = [NSMutableArray array];

    SCITWPage *page = [[SCITWPage alloc] init];
    page.order = order;
    page.title = title;
    page.note = note;
    page.symbol = symbol;
    page.tint = tint;
    page.builder = builder;
    [sciPages addObject:page];
}

+ (NSArray<SCITWPage *> *)pages {
    // Sorted here rather than on insert: `+load` order across files is not something a
    // reader of any one of them could predict, and a screen whose order depends on link
    // order is a screen that rearranges itself between builds.
    return [sciPages sortedArrayUsingComparator:^NSComparisonResult(SCITWPage *a, SCITWPage *b) {
        if (a.order == b.order) return NSOrderedSame;
        return a.order < b.order ? NSOrderedAscending : NSOrderedDescending;
    }];
}

+ (NSArray<SCITWSection *> *)sectionsForPage:(SCITWPage *)page host:(UIViewController *)host {
    if (!page.builder) return @[];

    NSMutableArray<SCITWSection *> *built = [NSMutableArray array];
    for (SCITWSection *section in page.builder(host)) {
        if (section.rows.count) [built addObject:section];
    }
    return built;
}

@end
