#import "SCIYTSettingsRegistry.h"

/// Registrations, kept in the order they must appear rather than the order they arrived.
///
/// A plain array of dictionaries rather than a class: this holds two fields and is read
/// once per screen, and a type for it would be a type nobody reads twice.
static NSMutableArray<NSDictionary *> *sciPages = nil;

@implementation SCIYTSettingsRegistry

+ (void)registerSectionsWithOrder:(NSInteger)order builder:(SCIYTSectionsBuilder)builder {
    if (!builder) return;

    // +load ordering is undefined, so this can run before any +initialize would have. Built
    // here rather than relying on one.
    if (!sciPages) sciPages = [NSMutableArray array];

    [sciPages addObject:@{@"order": @(order), @"builder": [builder copy]}];
}

+ (NSArray<SCISection *> *)composedSectionsFor:(SCIYTSettingsHostController *)host {
    NSArray *ordered = [sciPages sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,
                                                                               NSDictionary *b) {
        return [a[@"order"] compare:b[@"order"]];
    }];

    NSMutableArray<SCISection *> *sections = [NSMutableArray array];
    for (NSDictionary *page in ordered) {
        SCIYTSectionsBuilder builder = page[@"builder"];

        // A page that cannot build itself costs its own section and nothing else. The
        // settings screen has been the crash site twice in this project's history, and both
        // times one bad page took the whole screen with it.
        @try {
            NSArray<SCISection *> *built = builder(host);
            for (SCISection *section in built) {
                if (section.rows.count) [sections addObject:section];
            }
        } @catch (__unused NSException *exception) { }
    }
    return sections;
}

+ (NSUInteger)pageCount { return sciPages.count; }

@end
