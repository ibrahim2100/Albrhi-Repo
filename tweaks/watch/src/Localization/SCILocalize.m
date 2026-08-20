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

        // Shown on the watch's own Software Update page while the hold is on. iOS says the watch
        // is up to date, because that is what it was told; this says who told it.
        @"hold_notice": @"Albrhi Watch is holding watchOS updates. This page shows no update "
                        @"because Albrhi withheld it, not because none was published. Turn the "
                        @"hold off in Settings › Albrhi › Albrhi Watch to see it again.",
    };

    _arTable = @{
        @"title": @"البرهي للساعة",
        @"gate_off": @"مطفأة — شغّل البرهي للساعة من الإعدادات › البرهي",

        @"hold_notice": @"البرهي للساعة يمنع تحديثات watchOS. هذه الصفحة لا تُظهر تحديثاً لأن "
                        @"البرهي حجبه، لا لأنه غير موجود. أطفئ المنع من الإعدادات › البرهي › "
                        @"البرهي للساعة لتراه.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    BOOL arabic = [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"];
    NSString *value = arabic ? _arTable[key] : _enTable[key];
    return value ?: (_enTable[key] ?: key);
}
