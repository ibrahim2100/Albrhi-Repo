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
        @"panel_title": @"Albrhi Panel",

        @"section_summary": @"On this device",
        @"summary_apps": @"Apps being changed",
        @"summary_tweaks": @"Tweaks installed",

        @"section_apps": @"Apps",
        @"apps_footer": @"Only apps that at least one tweak targets. Tap one to see which.",
        @"apps_none": @"Nothing is targeting an app right now",

        @"section_tweaks": @"Tweaks",
        @"tweaks_footer": @"Read from each tweak's own filter file — the record of where it loads.",
        @"tweaks_none": @"No tweaks found on this device",

        @"count_one_app": @"1 app",
        @"count_apps": @"%lu apps",
        @"count_one_tweak": @"1 tweak",
        @"count_tweaks": @"%lu tweaks",
        @"targets_system": @"System",
        @"targets_by_class": @"Loads by class",

        @"app_switch_section": @"Albrhi",
        @"app_switch": @"Albrhi tweaks in this app",
        @"app_switch_footer": @"Turns Albrhi's own features off inside this app. Your settings are kept and come back when you turn it on again.",
        @"app_switch_restart": @"Close and reopen the app for this to take effect.",
        @"app_tweaks_section": @"Loaded into this app",
        @"app_others_footer": @"Tweaks by other developers are listed but cannot be switched from here yet.",
        @"ok": @"OK",

        @"section_about": @"About",
        @"about_version": @"Version",
        @"about_author": @"Made by",
        @"about_author_name": @"Ibrahim Ismail AL-Rahn",
        @"about_readonly_note": @"This version changes nothing. It reads what is on the device and shows it.",
    };

    _arTable = @{
        @"panel_title": @"لوحة البرهي",

        @"section_summary": @"على هذا الجهاز",
        @"summary_apps": @"تطبيقات مُعدَّلة",
        @"summary_tweaks": @"أدوات مثبَّتة",

        @"section_apps": @"التطبيقات",
        @"apps_footer": @"التطبيقات التي تستهدفها أداة واحدة على الأقل. اضغط واحداً لترى أيّها.",
        @"apps_none": @"لا شيء يستهدف تطبيقاً الآن",

        @"section_tweaks": @"الأدوات",
        @"tweaks_footer": @"مقروءة من ملفّ الفلتر الخاص بكل أداة — وهو سجلّ أين تُحمَّل.",
        @"tweaks_none": @"لا توجد أدوات على هذا الجهاز",

        @"count_one_app": @"تطبيق واحد",
        @"count_apps": @"%lu تطبيقات",
        @"count_one_tweak": @"أداة واحدة",
        @"count_tweaks": @"%lu أدوات",
        @"targets_system": @"النظام",
        @"targets_by_class": @"تُحمَّل حسب الصنف",

        @"app_switch_section": @"البرهي",
        @"app_switch": @"أدوات البرهي في هذا التطبيق",
        @"app_switch_footer": @"يُوقف مزايا البرهي داخل هذا التطبيق. إعداداتك محفوظة وتعود حين تُشغّله من جديد.",
        @"app_switch_restart": @"أغلق التطبيق وافتحه ليسري المفعول.",
        @"app_tweaks_section": @"مُحمَّل في هذا التطبيق",
        @"app_others_footer": @"أدوات المطوّرين الآخرين تُعرَض ولا يمكن تشغيلها من هنا بعد.",
        @"ok": @"حسناً",

        @"section_about": @"عن اللوحة",
        @"about_version": @"الإصدار",
        @"about_author": @"تطوير",
        @"about_author_name": @"إبراهيم إسماعيل الرهن",
        @"about_readonly_note": @"هذا الإصدار لا يُغيّر شيئاً. يقرأ ما على الجهاز ويعرضه.",
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
