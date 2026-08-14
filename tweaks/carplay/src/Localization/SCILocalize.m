#import "SCILocalize.h"

///
/// Every user-facing string, in both languages.
///
/// The two tables must hold the same keys; tools/check.py fails the build if they
/// drift, if a key is used but never defined, or if a stray quote inside a value
/// leaves Objective-C reading prose as code.
///
/// v0.1.0 has no settings screen yet -- see CHANGELOG.md for why -- so what is here is
/// only what the diagnostics report already prints. The table exists from the first
/// commit anyway, on purpose: every other tweak in this repository is bilingual from
/// its first release, and retrofitting a table after strings have accumulated in one
/// language is the more expensive order to do it in.
///

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"report_title": @"Albrhi CarPlay",
        @"report_audio_on": @"recording audio fix: on",
        @"report_audio_off": @"recording audio fix: off",
        @"report_screen_connected": @"CarPlay screen: connected",
        @"report_screen_disconnected": @"CarPlay screen: not connected",
        @"mic_automatic": @"Automatic",
        @"mic_iphone": @"iPhone",
        @"mic_car": @"Car",
    };

    _arTable = @{
        @"report_title": @"البرهي لكاربلاي",
        @"report_audio_on": @"إصلاح صوت التسجيل: مُفعَّل",
        @"report_audio_off": @"إصلاح صوت التسجيل: مُطفَأ",
        @"report_screen_connected": @"شاشة كاربلاي: متصلة",
        @"report_screen_disconnected": @"شاشة كاربلاي: غير متصلة",
        @"mic_automatic": @"تلقائي",
        @"mic_iphone": @"الآيفون",
        @"mic_car": @"السيارة",
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
