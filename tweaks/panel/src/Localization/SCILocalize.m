#import "SCILocalize.h"

///
/// Every user-facing string, in both languages.
///
/// The two tables must hold the same keys; tools/check.py fails the build if they
/// drift, if a key is used but never defined, or if a stray quote inside a value
/// leaves Objective-C reading prose as code.
///

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"panel_title": @"Albrhi",
        @"panel_tagline": @"One tweak for every app it supports, switched from here.",
        @"section_apps": @"Apps",
        @"section_versions": @"Versions",
        @"versions_footer": @"The app version each tweak was last verified against. A newer app usually still works — this is here so you can see the difference when something does not.",
        @"versions_match": @"%@ · tested",
        @"versions_differ": @"%@ · tested on %@",
        @"versions_tested_only": @"tested on %@",
        @"about_signature": @"Albrhi — made by Ibrahim Ismail AL-Rahn.\nFree and open source under the GNU GPL v3. The Instagram tweak is a derivative of SCInsta by SoCuul, whose authorship is credited and preserved.",
        @"apps_footer": @"Turn Albrhi off inside an app without uninstalling it. Your settings are kept and come back when you turn it on again.",
        @"apps_none": @"No Albrhi tweak is installed",
        @"switch_restart": @"Close and reopen the app for this to take effect.",
        @"ok": @"OK",
        @"section_about": @"About",
        @"about_version": @"Version",
        @"about_author": @"Made by",
        @"about_author_name": @"Ibrahim Ismail AL-Rahn",
        @"about_note": @"A greyed switch means that app is not installed on this device.",
    };

    _arTable = @{
        @"panel_title": @"البرهي",
        @"panel_tagline": @"أداة واحدة لكل تطبيق تدعمه، تتحكم بها من هنا.",
        @"section_apps": @"التطبيقات",
        @"section_versions": @"الإصدارات",
        @"versions_footer": @"إصدار التطبيق الذي جُرّبت عليه كل أداة آخر مرة. الإصدار الأحدث يعمل غالباً — وهذا القسم ليظهر لك الفرق حين لا يعمل.",
        @"versions_match": @"%@ · مُجرَّب",
        @"versions_differ": @"%@ · جُرِّب على %@",
        @"versions_tested_only": @"جُرِّب على %@",
        @"about_signature": @"البرهي — تطوير إبراهيم إسماعيل الرهن.\nحر ومفتوح المصدر تحت رخصة GNU GPL v3. أداة إنستغرام مشتقّة من SCInsta لـ SoCuul، ونسبتها إليه محفوظة ومذكورة.",
        @"apps_footer": @"أوقف البرهي داخل تطبيق بلا حذفه. إعداداتك محفوظة وتعود حين تُشغّله من جديد.",
        @"apps_none": @"لا توجد أداة برهي مثبَّتة",
        @"switch_restart": @"أغلق التطبيق وافتحه ليسري المفعول.",
        @"ok": @"حسناً",
        @"section_about": @"عن اللوحة",
        @"about_version": @"الإصدار",
        @"about_author": @"تطوير",
        @"about_author_name": @"إبراهيم إسماعيل الرهن",
        @"about_note": @"المفتاح الرمادي يعني أن ذلك التطبيق غير مثبَّت على هذا الجهاز.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCIBuildTables();
    });

    // The device's own preference. Someone whose phone is Arabic is an Arabic reader, and
    // these strings are the panel's own rather than any app's.
    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    BOOL arabic = [language hasPrefix:@"ar"];

    NSDictionary *table = arabic ? _arTable : _enTable;
    NSString *value = table[key];

    return value ?: (_enTable[key] ?: key);
}
