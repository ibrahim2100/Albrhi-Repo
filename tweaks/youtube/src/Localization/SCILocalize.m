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
        @"panel_title": @"Albrhi for YouTube",
        @"panel_subtitle": @"Hold two fingers anywhere to open this",
        @"panel_close": @"Close",

        @"verbose_logging": @"Verbose logging",
        @"verbose_logging_note": @"Writes what the tweak is doing to the system log. Leave this off unless you are collecting a report — it is noisy and slows things down.",

        @"diagnostics": @"Diagnostics",
        @"diagnostics_note": @"What the tweak actually finds in your copy of YouTube, and what YouTube said about the video you last played.",

        @"diag_title": @"Diagnostics",
        @"diag_copy": @"Copy report",
        @"diag_copied": @"Report copied",

        @"diag_build": @"Build",
        @"diag_tweak_version": @"Albrhi for YouTube",
        @"diag_app_version": @"YouTube",
        @"diag_bundle": @"Bundle",

        @"diag_attached": @"What attached",
        @"diag_present": @"found",
        @"diag_absent": @"missing",

        @"diag_panel_failed": @"The panel could not be built",

        @"diag_groups": @"Settings groups YouTube built",
        @"diag_groups_none": @"None seen yet. Open YouTube's settings once, then come back.",

        @"diag_video": @"Last video played",
        @"diag_no_video": @"Nothing yet. Play a video, then come back to this page.",
        @"diag_video_id": @"Video",
        @"diag_streams": @"Streams offered",
        @"diag_response": @"Full player response",
        @"diag_response_note": @"Everything YouTube told the app about that video. This is the part worth copying — it decides how downloading can work at all.",
    };

    _arTable = @{
        @"panel_title": @"البرهي ليوتيوب",
        @"panel_subtitle": @"اضغط بإصبعين في أي مكان لفتح هذه اللوحة",
        @"panel_close": @"إغلاق",

        @"verbose_logging": @"سجل مفصّل",
        @"verbose_logging_note": @"يكتب ما تفعله الأداة في سجل النظام. اتركه مطفأً إلا إذا كنت تجمع تقريرًا — فهو مزعج ويُبطئ الأداء.",

        @"diagnostics": @"التشخيص",
        @"diagnostics_note": @"ما تجده الأداة فعلًا في نسختك من يوتيوب، وما قاله يوتيوب عن آخر فيديو شغّلته.",

        @"diag_title": @"التشخيص",
        @"diag_copy": @"نسخ التقرير",
        @"diag_copied": @"تم نسخ التقرير",

        @"diag_build": @"النسخة",
        @"diag_tweak_version": @"البرهي ليوتيوب",
        @"diag_app_version": @"يوتيوب",
        @"diag_bundle": @"الحزمة",

        @"diag_attached": @"ما تم ربطه",
        @"diag_present": @"موجود",
        @"diag_absent": @"غير موجود",

        @"diag_panel_failed": @"تعذّر بناء اللوحة",

        @"diag_groups": @"مجموعات الإعدادات التي بناها يوتيوب",
        @"diag_groups_none": @"لم تُرَ بعد. افتح إعدادات يوتيوب مرة ثم ارجع.",

        @"diag_video": @"آخر فيديو شُغّل",
        @"diag_no_video": @"لا شيء بعد. شغّل فيديو ثم ارجع إلى هذه الصفحة.",
        @"diag_video_id": @"الفيديو",
        @"diag_streams": @"الصيغ المعروضة",
        @"diag_response": @"استجابة المشغّل كاملة",
        @"diag_response_note": @"كل ما قاله يوتيوب للتطبيق عن ذلك الفيديو. هذا هو الجزء الذي يستحق النسخ — فهو يحدّد كيف يمكن للتحميل أن يعمل أصلًا.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCIBuildTables();
    });

    // The device's own preference, not the app's. Someone whose phone is Arabic is an
    // Arabic reader even if they left YouTube in English, and this tweak's strings are
    // its own rather than YouTube's.
    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    BOOL arabic = [language hasPrefix:@"ar"];

    NSDictionary *table = arabic ? _arTable : _enTable;
    NSString *value = table[key];

    return value ?: (_enTable[key] ?: key);
}
