#import "SCIPages.h"

NSString *SCIScopeName(id tier) {
    if (![tier isKindOfClass:[NSString class]] || ![tier length]) return @"الكل";

    static NSDictionary *names = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @{
            @"suite":          @"الكل (جيلبريك)",
            @"apps":           @"الأدوات المنفصلة",
            @"app:instagram":  @"إنستغرام",
            @"app:youtube":    @"يوتيوب",
            @"app:twitter":    @"X",
            @"app:tiktok":     @"تيك توك",
            @"trial":          @"تجربة",
            @"lifetime":       @"الكل",
        };
    });

    NSString *known = names[tier];
    if (known) return known;

    // A store licence names its shop: store:na9 reads as "متجر na9" rather than as a raw value.
    if ([tier hasPrefix:@"store:"]) {
        return [@"متجر " stringByAppendingString:[tier substringFromIndex:6]];
    }
    return tier;
}
