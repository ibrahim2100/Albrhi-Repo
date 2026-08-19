#import "SCILocalize.h"

///
/// Every user-facing string this tweak owns, in both languages.
///
/// Short, because almost everything a person reads about this tweak is drawn by Albrhi Panel and
/// lives in the panel's own tables. What is here is what SpringBoard itself might have to say.
///
static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"title": @"Albrhi Watch",
        @"gate_off": @"Off — turn Albrhi Watch on in Settings › Albrhi",
    };

    _arTable = @{
        @"title": @"البرهي للساعة",
        @"gate_off": @"مطفأة — شغّل البرهي للساعة من الإعدادات › البرهي",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    BOOL arabic = [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"];
    NSString *value = arabic ? _arTable[key] : _enTable[key];
    return value ?: (_enTable[key] ?: key);
}
