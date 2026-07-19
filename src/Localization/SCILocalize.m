#import "SCILocalize.h"

@implementation SCILocalize

static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

+ (void)load {
    [self buildTables];
}

+ (NSString *)languageOverride {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:@"albrhi_language"];
    if (![v length]) return @"system";
    return v;
}

+ (void)setLanguageOverride:(NSString *)code {
    if ([code isEqualToString:@"system"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"albrhi_language"];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"albrhi_language"];
    }
}

+ (NSString *)activeLanguage {
    NSString *override = [self languageOverride];
    if ([override isEqualToString:@"ar"]) return @"ar";
    if ([override isEqualToString:@"en"]) return @"en";

    // System resolution
    NSString *pref = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    if ([pref hasPrefix:@"ar"]) return @"ar";
    return @"en";
}

+ (BOOL)isRTL {
    return [[self activeLanguage] isEqualToString:@"ar"];
}

+ (NSString *)stringForKey:(NSString *)key {
    if (![key length]) return @"";
    NSDictionary *table = [[self activeLanguage] isEqualToString:@"ar"] ? _arTable : _enTable;
    NSString *value = table[key];
    if (value) return value;
    // Fallback to English, then to the raw key
    return _enTable[key] ?: key;
}

+ (void)buildTables {
    _enTable = @{
        // General section
        @"section_general": @"General",
        @"hide_ads_title": @"Hide ads",
        @"hide_ads_sub": @"Removes all ads from the Instagram app",
        @"hide_meta_ai_title": @"Hide Meta AI",
        @"hide_meta_ai_sub": @"Hides the Meta AI buttons and functionality",
        @"copy_description_title": @"Copy description",
        @"copy_description_sub": @"Copy caption text by long-pressing on it",
        @"no_recent_searches_title": @"Do not save recent searches",
        @"no_recent_searches_sub": @"Search bars will no longer store your recent searches",
        @"detailed_color_picker_title": @"Detailed color picker",
        @"detailed_color_picker_sub": @"Long-press the eyedropper in stories for precise colors",
        @"teen_icons_title": @"Enable teen app icons",
        @"teen_icons_sub": @"Hold the Instagram logo to change the app icon",

        // Focus
        @"section_focus": @"Focus & Distraction",
        @"no_suggested_users_title": @"No suggested users",
        @"no_suggested_chats_title": @"No suggested chats",
        @"hide_trending_title": @"Hide trending searches",
        @"hide_explore_grid_title": @"Hide explore posts grid",

        // Feed
        @"section_feed": @"Feed",
        @"hide_story_tray_title": @"Hide stories tray",
        @"hide_feed_title": @"Hide entire feed",
        @"no_suggested_posts_title": @"No suggested posts",
        @"disable_autoplay_title": @"Disable video autoplay",

        // Reels
        @"section_reels": @"Reels",
        @"always_scrubber_title": @"Always show progress scrubber",
        @"no_autounmute_title": @"Disable auto-unmuting reels",
        @"confirm_refresh_title": @"Confirm reel refresh",
        @"hide_reels_header_title": @"Hide reels header",
        @"disable_scrolling_reels_title": @"Disable scrolling reels",
        @"limit_reels_title": @"Prevent doom scrolling",

        // Media / Downloads
        @"section_downloads": @"Downloads",
        @"dw_feed_posts_title": @"Download feed posts",
        @"dw_feed_posts_sub": @"Long-press a feed photo or video to download it",
        @"dw_reels_title": @"Download reels",
        @"dw_reels_sub": @"Long-press a reel to download it",
        @"dw_story_title": @"Download stories",
        @"dw_story_sub": @"Long-press a story to download it",
        @"save_profile_title": @"Save profile pictures",
        @"save_profile_sub": @"Long-press a profile picture to view/save it in HD",
        @"dw_max_quality_title": @"Always max quality",
        @"dw_max_quality_sub": @"Always pick the highest resolution/bitrate available",
        @"dw_save_to_camera_title": @"Save directly to Photos",
        @"dw_save_to_camera_sub": @"Save straight to your library instead of the share sheet",
        @"dw_reel_audio_title": @"Enable reel audio download",
        @"dw_reel_audio_sub": @"When downloading a reel, choose between the video or its audio",
        @"dw_choice_video": @"Download video",
        @"dw_choice_audio": @"Download audio only",
        @"show_quality_picker_title": @"Choose quality before download",
        @"show_quality_picker_sub": @"Show a list of available resolutions when downloading video",
        @"copy_account_info_title": @"Copy account info",
        @"copy_account_info_sub": @"Long-press a profile picture to copy the account's username and name",
        @"custom_album_title": @"Save to \"Albrhi\" album",
        @"custom_album_sub": @"Organize saved media into a dedicated album in Photos",
        @"accent_color_title": @"Accent color",
        @"accent_color_sub": @"Customize Albrhi's highlight color",
        @"accent_reset_title": @"Reset accent color",
        @"info_download_pfp": @"Download profile picture",
        @"info_copy": @"Copy account info",
        @"info_copied": @"Account info copied",
        @"info_unavailable": @"Account info unavailable",
        @"info_verified": @"✓ Verified",
        @"quality_unknown": @"Unknown quality",
        @"quality_pick_title": @"Choose quality",
        @"dw_silent_video_title": @"Download videos without audio",
        @"dw_silent_video_sub": @"Strips the audio track from downloaded videos",
        @"dw_finger_duration_title": @"Long-press duration",
        @"dw_finger_count_title": @"Fingers required",

        // Privacy
        @"section_privacy": @"Privacy",
        @"disable_story_seen_title": @"Disable story seen receipts",
        @"disable_typing_title": @"Disable typing status",
        @"keep_deleted_msgs_title": @"Keep deleted messages",
        @"no_screenshot_alert_title": @"No screenshot alerts",

        // Language
        @"section_language": @"Language",
        @"language_title": @"Language",
        @"language_sub": @"Choose Albrhi's interface language",
        @"language_system": @"System default",
        @"language_arabic": @"العربية (Arabic)",
        @"language_english": @"English",

        // Settings meta
        @"settings_title": @"Albrhi Settings",
        @"settings_header": @"Albrhi",
        @"quick_access_title": @"Settings quick-access",
        @"quick_access_sub": @"Hold the home tab to open Albrhi settings",
        @"open_on_launch_title": @"Open settings on launch",
        @"reset_first_run_title": @"Reset first-run flag",
        @"credits_title": @"Credits",
        @"credits_sub": @"Albrhi is based on SCInsta by SoCuul (GPLv3)",
        @"view_repo_title": @"View source",
        @"view_repo_sub": @"Albrhi is open-source under the GPLv3 license",
        @"developer_title": @"Developer",

        // Runtime messages
        @"restart_required": @"Restart required",
        @"restart_message": @"Instagram must be restarted for this change to take effect.",
        @"restart_now": @"Restart now",
        @"later": @"Later",
        @"download_started": @"Downloading…",
        @"download_saved": @"Saved to Photos",
        @"download_failed": @"Download failed",
        @"err_no_photo": @"Could not extract photo URL",
        @"err_no_video": @"Could not extract video URL",
        @"loading": @"Loading",
        @"cancel": @"Cancel",
    };

    _arTable = @{
        // عام
        @"section_general": @"عام",
        @"hide_ads_title": @"إخفاء الإعلانات",
        @"hide_ads_sub": @"يزيل جميع الإعلانات من تطبيق انستقرام",
        @"hide_meta_ai_title": @"إخفاء Meta AI",
        @"hide_meta_ai_sub": @"يخفي أزرار ووظائف الذكاء الاصطناعي من ميتا",
        @"copy_description_title": @"نسخ الوصف",
        @"copy_description_sub": @"انسخ نص الوصف بالضغط المطوّل عليه",
        @"no_recent_searches_title": @"عدم حفظ عمليات البحث الأخيرة",
        @"no_recent_searches_sub": @"لن يحفظ شريط البحث عمليات بحثك الأخيرة",
        @"detailed_color_picker_title": @"منتقي ألوان مفصّل",
        @"detailed_color_picker_sub": @"اضغط مطوّلًا على أداة القطارة في القصص لألوان أدق",
        @"teen_icons_title": @"تفعيل أيقونات التطبيق",
        @"teen_icons_sub": @"اضغط مطوّلًا على شعار انستقرام لتغيير أيقونة التطبيق",

        // التركيز
        @"section_focus": @"التركيز وتقليل التشتّت",
        @"no_suggested_users_title": @"إخفاء الحسابات المقترحة",
        @"no_suggested_chats_title": @"إخفاء المحادثات المقترحة",
        @"hide_trending_title": @"إخفاء عمليات البحث الرائجة",
        @"hide_explore_grid_title": @"إخفاء شبكة منشورات الاستكشاف",

        // الصفحة الرئيسية
        @"section_feed": @"الصفحة الرئيسية",
        @"hide_story_tray_title": @"إخفاء شريط القصص",
        @"hide_feed_title": @"إخفاء الصفحة الرئيسية بالكامل",
        @"no_suggested_posts_title": @"إخفاء المنشورات المقترحة",
        @"disable_autoplay_title": @"تعطيل التشغيل التلقائي للفيديو",

        // الريلز
        @"section_reels": @"الريلز",
        @"always_scrubber_title": @"إظهار شريط التقدّم دائمًا",
        @"no_autounmute_title": @"تعطيل إلغاء الكتم التلقائي",
        @"confirm_refresh_title": @"تأكيد تحديث الريلز",
        @"hide_reels_header_title": @"إخفاء رأس الريلز",
        @"disable_scrolling_reels_title": @"تعطيل التمرير في الريلز",
        @"limit_reels_title": @"منع التمرير المفرط",

        // التنزيلات
        @"section_downloads": @"التنزيلات",
        @"dw_feed_posts_title": @"تنزيل منشورات الصفحة",
        @"dw_feed_posts_sub": @"اضغط مطوّلًا على صورة أو فيديو لتنزيله",
        @"dw_reels_title": @"تنزيل الريلز",
        @"dw_reels_sub": @"اضغط مطوّلًا على الريل لتنزيله",
        @"dw_story_title": @"تنزيل القصص",
        @"dw_story_sub": @"اضغط مطوّلًا على القصة لتنزيلها",
        @"save_profile_title": @"حفظ صور الملف الشخصي",
        @"save_profile_sub": @"اضغط مطوّلًا على صورة الملف الشخصي لعرضها/حفظها بجودة عالية",
        @"dw_max_quality_title": @"أعلى جودة دائمًا",
        @"dw_max_quality_sub": @"اختيار أعلى دقة/معدل بت متاح دائمًا",
        @"dw_save_to_camera_title": @"الحفظ مباشرة في الصور",
        @"dw_save_to_camera_sub": @"احفظ مباشرة في مكتبة الصور بدل قائمة المشاركة",
        @"dw_reel_audio_title": @"تفعيل تنزيل صوت الريلز",
        @"dw_reel_audio_sub": @"عند تنزيل ريل، اختر بين الفيديو أو الصوت فقط",
        @"dw_choice_video": @"تنزيل الفيديو",
        @"dw_choice_audio": @"تنزيل الصوت فقط",
        @"show_quality_picker_title": @"اختيار الجودة قبل التنزيل",
        @"show_quality_picker_sub": @"عرض قائمة بالدقّات المتاحة عند تنزيل الفيديو",
        @"copy_account_info_title": @"نسخ معلومات الحساب",
        @"copy_account_info_sub": @"اضغط مطوّلًا على صورة الملف الشخصي لنسخ اسم المستخدم والاسم",
        @"custom_album_title": @"الحفظ في ألبوم \"Albrhi\"",
        @"custom_album_sub": @"تنظيم الوسائط المحفوظة في ألبوم مخصّص داخل الصور",
        @"accent_color_title": @"لون التمييز",
        @"accent_color_sub": @"خصّص لون Albrhi المميّز",
        @"accent_reset_title": @"إعادة تعيين اللون",
        @"info_download_pfp": @"تنزيل صورة الملف الشخصي",
        @"info_copy": @"نسخ معلومات الحساب",
        @"info_copied": @"تم نسخ معلومات الحساب",
        @"info_unavailable": @"معلومات الحساب غير متاحة",
        @"info_verified": @"✓ موثّق",
        @"quality_unknown": @"جودة غير معروفة",
        @"quality_pick_title": @"اختر الجودة",
        @"dw_silent_video_title": @"تنزيل الفيديو بدون صوت",
        @"dw_silent_video_sub": @"إزالة مسار الصوت من الفيديوهات المنزّلة",
        @"dw_finger_duration_title": @"مدة الضغط المطوّل",
        @"dw_finger_count_title": @"عدد الأصابع المطلوبة",

        // الخصوصية
        @"section_privacy": @"الخصوصية",
        @"disable_story_seen_title": @"تعطيل إشعار مشاهدة القصة",
        @"disable_typing_title": @"تعطيل حالة الكتابة",
        @"keep_deleted_msgs_title": @"إبقاء الرسائل المحذوفة",
        @"no_screenshot_alert_title": @"إلغاء تنبيه لقطة الشاشة",

        // اللغة
        @"section_language": @"اللغة",
        @"language_title": @"اللغة",
        @"language_sub": @"اختر لغة واجهة Albrhi",
        @"language_system": @"لغة النظام",
        @"language_arabic": @"العربية",
        @"language_english": @"English (الإنجليزية)",

        // إعدادات
        @"settings_title": @"إعدادات Albrhi",
        @"settings_header": @"Albrhi",
        @"quick_access_title": @"وصول سريع للإعدادات",
        @"quick_access_sub": @"اضغط مطوّلًا على تبويب الرئيسية لفتح إعدادات Albrhi",
        @"open_on_launch_title": @"فتح الإعدادات عند التشغيل",
        @"reset_first_run_title": @"إعادة تعيين شاشة الترحيب",
        @"credits_title": @"شكر وتقدير",
        @"credits_sub": @"Albrhi مبني على SCInsta من SoCuul (رخصة GPLv3)",
        @"view_repo_title": @"عرض الشيفرة المصدرية",
        @"view_repo_sub": @"Albrhi مفتوح المصدر تحت رخصة GPLv3",
        @"developer_title": @"المطوّر",

        // رسائل التشغيل
        @"restart_required": @"إعادة التشغيل مطلوبة",
        @"restart_message": @"يجب إعادة تشغيل انستقرام لتطبيق هذا التغيير.",
        @"restart_now": @"إعادة التشغيل الآن",
        @"later": @"لاحقًا",
        @"download_started": @"جارٍ التنزيل…",
        @"download_saved": @"تم الحفظ في الصور",
        @"download_failed": @"فشل التنزيل",
        @"err_no_photo": @"تعذّر استخراج رابط الصورة",
        @"err_no_video": @"تعذّر استخراج رابط الفيديو",
        @"loading": @"جارٍ التحميل",
        @"cancel": @"إلغاء",
    };
}

@end
