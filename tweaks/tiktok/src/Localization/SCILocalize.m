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

        @"section_controls": @"Controls",
        @"section_privacy": @"Privacy",
        @"section_download": @"Download",
        @"section_status": @"Status",

        @"row_ads": @"Hide ads",
        @"row_ads_note": @"A feed item marked as an ad by TikTok's own server is never built into a cell.",
        @"row_download_button": @"Download button in the feed",
        @"row_download_button_note": @"A button beside like, comment and share on the video on screen.",
        @"row_bypass": @"Hide the jailbreak",
        @"row_bypass_note": @"Answers TikTok's own device checks the way an unmodified phone would.",

        @"row_privacy_story": @"Story views",
        @"row_privacy_story_note": @"Stops the seen mark a story's author would otherwise get.",
        @"row_privacy_messages": @"Message read receipts",
        @"row_privacy_messages_note": @"Stops the read receipt sent to the other side. Your own unread badge still clears normally.",
        @"row_privacy_profile": @"Profile views",
        @"row_privacy_profile_note": @"Stops the report sent when you open someone's profile.",

        @"pill_ads": @"Ads",
        @"pill_button": @"Button",
        @"pill_bypass": @"Bypass",

        @"status_gate": @"Panel switch",
        @"gate_on": @"On",
        @"gate_off": @"Off — turn TikTok on in Settings › Albrhi",

        @"status_button": @"In-feed button",
        @"status_media_resolve": @"Video link resolution",
        @"status_media_candidates": @"Possible video accessors",

        @"diag_ads": @"Ad filter",
        @"diag_ads_none": @"Nothing seen yet. Scroll the feed, then come back.",
        @"diag_ads_counts": @"%lu dropped of %lu feed items seen",

        @"diag_bypass": @"Bypass",
        @"diag_bypass_none": @"Nothing asked yet.",

        @"diag_privacy": @"Privacy",
        @"diag_privacy_none": @"Nothing asked yet.",

        @"media_title": @"Ready to save",
        @"media_empty": @"Nothing yet. Scroll the feed, then come back.",
        @"media_save": @"Save",
        @"media_footer": @"Tap a row to save it. Newest first.",

        @"save_working": @"Saving…",
        @"save_failed": @"Couldn't save it",
        @"save_done": @"Saved to Photos",
        @"save_done_audio": @"Sound saved",
        @"save_no_permission": @"Photos access is off",

        @"credit": @"Architecture read from BandarHL's and al3raQe's BHTikTok, NA9 For TikTok and VibeTok — none copied from.",
        @"report_copied": @"Report copied",
    };

    _arTable = @{
        @"title": @"البرهي لتيك توك",
        @"done": @"تم",

        @"section_controls": @"التحكم",
        @"section_privacy": @"الخصوصية",
        @"section_download": @"التحميل",
        @"section_status": @"الحالة",

        @"row_ads": @"إخفاء الإعلانات",
        @"row_ads_note": @"أي عنصر يعلّمه سيرفر تيك توك نفسه كإعلان لا يُبنى ككائن أصلاً.",
        @"row_download_button": @"زر تحميل في الواجهة",
        @"row_download_button_note": @"زر بجانب اللايك والتعليق والمشاركة على الفيديو المعروض.",
        @"row_bypass": @"إخفاء الجيلبريك",
        @"row_bypass_note": @"يجاوب على فحوصات تيك توك للجهاز كأنه جهاز غير معدَّل.",

        @"row_privacy_story": @"مشاهدة القصص",
        @"row_privacy_story_note": @"يوقف علامة المشاهدة اللي يشوفها صاحب القصة.",
        @"row_privacy_messages": @"تأكيد قراءة الرسائل",
        @"row_privacy_messages_note": @"يوقف تأكيد القراءة اللي يوصل للطرف الثاني. الشارة عندك تستمر تُمسح بشكل طبيعي.",
        @"row_privacy_profile": @"زيارة البروفايلات",
        @"row_privacy_profile_note": @"يوقف التقرير اللي يُرسل عند فتحك لبروفايل أحد.",

        @"pill_ads": @"الإعلانات",
        @"pill_button": @"الزر",
        @"pill_bypass": @"الإخفاء",

        @"status_gate": @"مفتاح البانل",
        @"gate_on": @"مفعّل",
        @"gate_off": @"مغلق — فعّل تيك توك من الإعدادات › البرهي",

        @"status_button": @"زر الواجهة",
        @"status_media_resolve": @"تحليل رابط الفيديو",
        @"status_media_candidates": @"دوال محتملة للفيديو",

        @"diag_ads": @"فلتر الإعلانات",
        @"diag_ads_none": @"لا شيء بعد. مرّر بالفيد ثم ارجع.",
        @"diag_ads_counts": @"%lu مُسقَط من %lu عنصر فيد",

        @"diag_bypass": @"الإخفاء",
        @"diag_bypass_none": @"لا شيء سُئل بعد.",

        @"diag_privacy": @"الخصوصية",
        @"diag_privacy_none": @"لا شيء سُئل بعد.",

        @"media_title": @"جاهز للحفظ",
        @"media_empty": @"لا شيء بعد. مرّر بالفيد ثم ارجع.",
        @"media_save": @"حفظ",
        @"media_footer": @"اضغط على أي صف لحفظه. الأحدث أولاً.",

        @"save_working": @"جارِ الحفظ…",
        @"save_failed": @"تعذّر الحفظ",
        @"save_done": @"تم الحفظ في الصور",
        @"save_done_audio": @"تم حفظ الصوت",
        @"save_no_permission": @"صلاحية الصور مغلقة",

        @"credit": @"البنية مقروءة من BHTikTok لـ BandarHL وal3raQe، وNA9 For TikTok وVibeTok — لا شيء منسوخ منها.",
        @"report_copied": @"تم نسخ التقرير",
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
