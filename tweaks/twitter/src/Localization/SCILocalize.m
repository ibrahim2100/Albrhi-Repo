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
        @"title": @"Albrhi for X",
        @"done": @"Done",
        @"cancel": @"Cancel",
        @"ok": @"OK",

        @"section_status": @"Status",
        @"status_providers": @"Places hooked",
        @"status_providers_none": @"none found",
        @"status_keys": @"Switches seen",
        @"status_asked": @"Questions answered",
        @"status_gate": @"Albrhi in X",
        @"gate_on": @"On",
        @"gate_off": @"Off — turn it on in Settings › Albrhi",

        @"section_keys": @"Switches",
        @"keys_footer": @"This is what X asked about while you were using it, not a list written in advance. Use the app for a while and more will appear. Tap one to answer it yourself.",
        @"keys_empty": @"Nothing yet. Scroll around X and come back.",
        @"search_placeholder": @"Search",

        @"filter_all": @"All",
        @"filter_changed": @"Changed",

        @"detail_app_on": @"X says on",
        @"detail_app_off": @"X says off",
        @"detail_you_on": @"You say on",
        @"detail_you_off": @"You say off",
        @"detail_asked": @"asked %lu×",

        @"choose_default": @"Let X decide",
        @"choose_on": @"On",
        @"choose_off": @"Off",

        @"menu_reset": @"Undo all my answers",
        @"menu_reset_body": @"Every switch goes back to whatever X decides. Nothing else changes.",
        @"menu_report": @"Save a report",
        @"report_saved": @"Saved to Files › On My iPhone › X › %@",
        @"report_failed": @"Could not save the report.",

        @"restart_note": @"Some changes only show after you close X and open it again.",
        @"credit": @"Albrhi — made by Ibrahim Ismail AL-Rahn. Free and open source under the GNU GPL v3. Where to hook this app was learned from the published work of BandarHL (BHTwitter) and TWIGalaxy; no code is taken from either.",
    };

    _arTable = @{
        @"title": @"البرهي لإكس",
        @"done": @"تم",
        @"cancel": @"إلغاء",
        @"ok": @"حسناً",

        @"section_status": @"الحالة",
        @"status_providers": @"المواضع المربوطة",
        @"status_providers_none": @"لم يُعثر على شيء",
        @"status_keys": @"المفاتيح التي ظهرت",
        @"status_asked": @"الأسئلة المُجاب عنها",
        @"status_gate": @"البرهي داخل إكس",
        @"gate_on": @"مُفعّل",
        @"gate_off": @"مُطفأ — فعّله من الإعدادات › البرهي",

        @"section_keys": @"المفاتيح",
        @"keys_footer": @"هذا ما سأل عنه إكس أثناء استخدامك، لا قائمة مكتوبة مسبقاً. استخدم التطبيق قليلاً وستظهر مفاتيح أكثر. اضغط على أي مفتاح لتجيب أنت عنه.",
        @"keys_empty": @"لا شيء بعد. تصفّح إكس قليلاً ثم ارجع.",
        @"search_placeholder": @"بحث",

        @"filter_all": @"الكل",
        @"filter_changed": @"المُعدَّلة",

        @"detail_app_on": @"إكس يقول: مُفعّل",
        @"detail_app_off": @"إكس يقول: مُطفأ",
        @"detail_you_on": @"أنت تقول: مُفعّل",
        @"detail_you_off": @"أنت تقول: مُطفأ",
        @"detail_asked": @"سُئل %lu مرة",

        @"choose_default": @"اترك القرار لإكس",
        @"choose_on": @"مُفعّل",
        @"choose_off": @"مُطفأ",

        @"menu_reset": @"تراجع عن كل إجاباتي",
        @"menu_reset_body": @"يعود كل مفتاح إلى ما يقرره إكس. لا يتغير شيء آخر.",
        @"menu_report": @"حفظ تقرير",
        @"report_saved": @"حُفظ في الملفات › على الآيفون › إكس › %@",
        @"report_failed": @"تعذّر حفظ التقرير.",

        @"restart_note": @"بعض التغييرات لا تظهر إلا بعد إغلاق إكس وفتحه من جديد.",
        @"credit": @"البرهي — تطوير إبراهيم إسماعيل الرهن. حر ومفتوح المصدر تحت رخصة GNU GPL v3. موضع الربط في هذا التطبيق عُرف من عمل BandarHL‏ (BHTwitter) وTWIGalaxy المنشور، ولم يُنسخ منهما أي كود.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCIBuildTables();
    });

    // The device's own preference. Someone whose phone is Arabic is an Arabic reader, and
    // these strings are this tweak's own rather than X's.
    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    BOOL arabic = [language hasPrefix:@"ar"];

    NSDictionary *table = arabic ? _arTable : _enTable;
    NSString *value = table[key];

    return value ?: (_enTable[key] ?: key);
}
