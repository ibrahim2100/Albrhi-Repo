#import "SCILocalize.h"

///
/// Every user-facing string, in both languages.
///
/// The two tables must hold the same keys; tools/check.py fails the build if they drift, if
/// a key is used but never defined, or if a stray quote inside a value leaves Objective-C
/// reading prose as code.
///

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"title": @"Albrhi for TikTok",
        @"done": @"Done",

        @"row_ads": @"Hide ads",
        @"row_bypass": @"Hide the jailbreak",

        @"diag_ads": @"Ad filter",
        @"diag_ads_none": @"Nothing seen yet. Scroll the feed, then come back.",
        @"diag_ads_counts": @"%lu dropped of %lu feed items seen",

        @"diag_bypass": @"Bypass",
        @"diag_bypass_none": @"Nothing asked yet.",
    };

    _arTable = @{
        @"title": @"البرهي لتيك توك",
        @"done": @"تم",

        @"row_ads": @"إخفاء الإعلانات",
        @"row_bypass": @"إخفاء الجيلبريك",

        @"diag_ads": @"فلتر الإعلانات",
        @"diag_ads_none": @"لا شيء بعد. مرّر بالفيد ثم ارجع.",
        @"diag_ads_counts": @"%lu مُسقَط من %lu عنصر فيد",

        @"diag_bypass": @"الإخفاء",
        @"diag_bypass_none": @"لا شيء سُئل بعد.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCIBuildTables();
    });

    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    BOOL arabic = [language hasPrefix:@"ar"];

    NSDictionary *table = arabic ? _arTable : _enTable;
    NSString *value = table[key];

    return value ?: (_enTable[key] ?: key);
}
