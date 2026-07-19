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
        @"section_connect": @"Connect with the developer",
        @"social_instagram_title": @"Instagram",
        @"social_snapchat_title": @"Snapchat",
        @"social_telegram_title": @"Telegram",
        @"social_open_sub": @"Opens the profile directly",

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
        @"err_no_media": @"Could not find media to download",

        // Diagnostics
        @"diag_title": @"Diagnostics",
        @"diag_sub": @"What Albrhi actually sees at runtime",
        @"diag_section_classes": @"Action row classes in this build",
        @"diag_section_attached": @"Download button attachments",
        @"diag_section_quality": @"Last video download",
        @"diag_section_stories": @"Stories",
        @"diag_section_env": @"Environment",
        @"diag_class_present": @"Exists in this Instagram build",
        @"diag_class_absent": @"Not present",
        @"diag_attached": @"Button attached here",
        @"diag_button_media": @"Media resolved on last press",
        @"diag_button_unpressed": @"Button not pressed yet",
        @"diag_button_nomedia": @"Nothing found — this is the download failure",
        @"diag_none_attached": @"No action row seen yet",
        @"diag_none_attached_hint": @"Scroll your feed once, then reopen this page",
        @"diag_quality_never": @"No video downloaded yet this session",
        @"diag_quality_single": @"Only %ld rendition found — no choice to offer",
        @"diag_quality_multi": @"%ld renditions found",
        @"diag_quality_last": @"Renditions",
        @"diag_quality_source": @"Video class",
        @"diag_download_kind": @"Last download treated as",
        @"diag_quality_raw": @"Renditions from API (before filtering)",
        @"diag_on": @"On",
        @"diag_off": @"Off",
        @"diag_story_intercepts": @"Seen receipts blocked",
        @"diag_copied": @"Report copied",
        @"diag_section_scan": @"Live screen scan",
        @"diag_scan_prompt": @"Not scanned yet",
        @"diag_scan_hint": @"Open a feed post behind this sheet, then tap the magnifier above",
        @"diag_scan_empty": @"Nothing button-row shaped on screen",

        // Story seen button
        @"story_seen_button_title": @"Mark-as-seen button",
        @"story_seen_button_sub": @"Adds an eye toggle in the story viewer to register a story as seen",
        @"story_seen_on": @"Seen receipts on",
        @"story_seen_off": @"Seen receipts off",
        @"story_seen_on_toast": @"Stories you watch now will be marked as seen",
        @"story_seen_off_toast": @"Watching invisibly again",

        // Welcome / What's New
        @"wn_welcome_title": @"Welcome to Albrhi",
        @"wn_welcome_sub": @"Instagram, minus the parts nobody asked for.",
        @"wn_update_title": @"Albrhi %@",
        @"wn_update_sub": @"Here's what changed while you were scrolling.",
        @"wn_continue": @"Let's go",

        @"wn_w1_title": @"Download anything",
        @"wn_w1_detail": @"Posts, reels, stories, carousels — always at the highest quality available.",
        @"wn_w2_title": @"A quieter feed",
        @"wn_w2_detail": @"Ads, suggested posts and Meta AI, politely shown the door.",
        @"wn_w3_title": @"Watch without a trace",
        @"wn_w3_detail": @"View stories with no seen receipt, and hide the typing indicator.",
        @"wn_w4_title": @"Find the settings",
        @"wn_w4_detail": @"Hold the ☰ button on your profile. Yes, that's the whole trick.",

        @"wn_u1_title": @"One-tap downloads",
        @"wn_u1_detail": @"A download button now sits in the post action row, next to save.",
        @"wn_u2_title": @"Download Center",
        @"wn_u2_detail": @"A real queue — pause, resume, retry, and a history of everything you saved.",
        @"wn_u3_title": @"Quality picker, everywhere",
        @"wn_u3_detail": @"It used to work on feed videos only. Reels and stories were quietly ignoring you.",
        @"wn_u4_title": @"Rebuilt underneath",
        @"wn_u4_detail": @"Settings are modular now, so features stop stepping on each other.",

        @"wn_show_again": @"Show the welcome screen again",
        @"wn_footnote_welcome": @"Free, open source, and not affiliated with Instagram — they have no idea we're here.",
        @"wn_footnote_update": @"No new ads were added in the making of this update.",

        // Download Center
        @"dl_center_title": @"Download Center",
        @"dl_center_sub": @"Queue, progress and history for every download",
        @"dl_section_active": @"Active",
        @"dl_section_history": @"History",
        @"dl_total_footer": @"%@ downloaded in total",
        @"dl_search_placeholder": @"Search downloads",
        @"dl_scope_all": @"All",
        @"dl_kind_photo": @"Photo",
        @"dl_kind_video": @"Video",
        @"dl_kind_audio": @"Audio",
        @"dl_kind_file": @"File",
        @"dl_state_queued": @"Waiting…",
        @"dl_state_paused": @"Paused",
        @"dl_state_failed": @"Failed",
        @"dl_state_cancelled": @"Cancelled",
        @"dl_size_of": @"%@ of %@",
        @"dl_pause": @"Pause",
        @"dl_resume": @"Resume",
        @"dl_retry": @"Retry",
        @"dl_cancel": @"Cancel",
        @"dl_pause_all": @"Pause all",
        @"dl_resume_all": @"Resume all",
        @"dl_clear_history": @"Clear history",
        @"dl_clear_history_message": @"Removes every finished download from the list. The saved files are not deleted.",
        @"dl_share": @"Share",
        @"dl_copy_link": @"Copy link",
        @"dl_remove": @"Remove",
        @"dl_sort_title": @"Sort by",
        @"dl_sort_newest": @"Newest first",
        @"dl_sort_oldest": @"Oldest first",
        @"dl_sort_name": @"Name",
        @"dl_sort_size": @"Size",
        @"dl_empty_title": @"No downloads yet",
        @"dl_empty_sub": @"Media you save will appear here, with progress and history.",
        @"dl_use_queue_title": @"Use the download queue",
        @"dl_use_queue_sub": @"Downloads run in the background and continue if you leave the app",
        @"dl_max_concurrent_title": @"Simultaneous downloads",
        @"dl_clear_title": @"Clear after saving",
        @"dl_clear_sub": @"Removes the download from this list once it is in Photos, so nothing is stored twice",
        @"dl_added_to_queue": @"Added to queue",
        @"dl_already_downloaded": @"Already downloaded",

        // Feature page titles
        @"page_general": @"General",
        @"page_feed": @"Feed",
        @"page_reels": @"Reels",
        @"page_stories_messages": @"Stories and messages",
        @"page_navigation": @"Navigation",
        @"page_confirmations": @"Confirm actions",

        @"inline_download_title": @"Inline download button",
        @"inline_download_sub": @"Adds a download icon to the post action row, next to save",
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
        @"section_connect": @"تواصل مع المطوّر",
        @"social_instagram_title": @"انستقرام",
        @"social_snapchat_title": @"سناب شات",
        @"social_telegram_title": @"تليقرام",
        @"social_open_sub": @"يفتح الحساب مباشرة",

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
        @"err_no_media": @"تعذّر العثور على الوسائط المطلوب تنزيلها",

        // التشخيص
        @"diag_title": @"التشخيص",
        @"diag_sub": @"ما تراه Albrhi فعليًا أثناء التشغيل",
        @"diag_section_classes": @"أصناف شريط الأزرار في هذا الإصدار",
        @"diag_section_attached": @"ارتباطات زر التنزيل",
        @"diag_section_quality": @"آخر تنزيل فيديو",
        @"diag_section_stories": @"القصص",
        @"diag_section_env": @"البيئة",
        @"diag_class_present": @"موجود في نسخة انستقرام هذه",
        @"diag_class_absent": @"غير موجود",
        @"diag_attached": @"الزر مرتبط هنا",
        @"diag_button_media": @"الوسائط المُستخرجة عند آخر ضغطة",
        @"diag_button_unpressed": @"لم يُضغط الزر بعد",
        @"diag_button_nomedia": @"لم يُعثر على شيء — هذا سبب فشل التنزيل",
        @"diag_none_attached": @"لم يُرصد أي شريط أزرار بعد",
        @"diag_none_attached_hint": @"مرّر في الصفحة الرئيسية مرة، ثم أعد فتح هذه الصفحة",
        @"diag_quality_never": @"لم يُنزَّل أي فيديو في هذه الجلسة",
        @"diag_quality_single": @"وُجدت %ld نسخة فقط — لا يوجد خيار لعرضه",
        @"diag_quality_multi": @"وُجدت %ld نسخ",
        @"diag_quality_last": @"النسخ المتاحة",
        @"diag_quality_source": @"صنف الفيديو",
        @"diag_download_kind": @"آخر تنزيل عومل كـ",
        @"diag_quality_raw": @"النسخ من الـ API (قبل الترشيح)",
        @"diag_on": @"مفعّل",
        @"diag_off": @"مطفأ",
        @"diag_story_intercepts": @"إشعارات مشاهدة مُوقَفة",
        @"diag_copied": @"تم نسخ التقرير",
        @"diag_section_scan": @"مسح الشاشة الحيّة",
        @"diag_scan_prompt": @"لم يُجرَ المسح بعد",
        @"diag_scan_hint": @"افتح منشورًا خلف هذه الصفحة، ثم اضغط زر العدسة أعلاه",
        @"diag_scan_empty": @"لا يوجد ما يشبه شريط أزرار على الشاشة",

        // زر مشاهدة القصة
        @"story_seen_button_title": @"زر تعليم كمشاهَد",
        @"story_seen_button_sub": @"يضيف زر عين في عارض القصص لتسجيل القصة كمشاهَدة",
        @"story_seen_on": @"إشعار المشاهدة مفعّل",
        @"story_seen_off": @"إشعار المشاهدة مطفأ",
        @"story_seen_on_toast": @"القصص التي تشاهدها الآن ستُسجَّل كمشاهَدة",
        @"story_seen_off_toast": @"عدت للمشاهدة المتخفية",

        // الترحيب وما الجديد
        @"wn_welcome_title": @"أهلًا بك في Albrhi",
        @"wn_welcome_sub": @"انستقرام، ناقصًا الأشياء التي لم يطلبها أحد.",
        @"wn_update_title": @"Albrhi %@",
        @"wn_update_sub": @"إليك ما تغيّر بينما كنت تتصفّح.",
        @"wn_continue": @"يلا نبدأ",

        @"wn_w1_title": @"نزّل أي شيء",
        @"wn_w1_detail": @"منشورات، ريلز، قصص، ألبومات — دائمًا بأعلى جودة متاحة.",
        @"wn_w2_title": @"صفحة رئيسية أهدأ",
        @"wn_w2_detail": @"الإعلانات والمنشورات المقترحة وMeta AI… ودّعناهم بأدب.",
        @"wn_w3_title": @"شاهد بلا أثر",
        @"wn_w3_detail": @"افتح القصص بدون أن يظهر اسمك، وأخفِ مؤشّر «يكتب الآن».",
        @"wn_w4_title": @"وين الإعدادات؟",
        @"wn_w4_detail": @"اضغط مطوّلًا على ☰ في ملفك الشخصي. نعم، هذه كل الحيلة.",

        @"wn_u1_title": @"تحميل بضغطة واحدة",
        @"wn_u1_detail": @"زر تنزيل صار في شريط أزرار المنشور، بجانب زر الحفظ.",
        @"wn_u2_title": @"مركز التنزيلات",
        @"wn_u2_detail": @"طابور حقيقي — إيقاف واستئناف وإعادة محاولة، وسجل بكل ما حفظته.",
        @"wn_u3_title": @"اختيار الجودة، في كل مكان",
        @"wn_u3_detail": @"كان يعمل على فيديو الصفحة الرئيسية فقط. الريلز والقصص كانت تتجاهلك بهدوء.",
        @"wn_u4_title": @"إعادة بناء من الداخل",
        @"wn_u4_detail": @"الإعدادات صارت وحدات مستقلة، فتوقّفت المزايا عن الدوس على بعضها.",

        @"wn_show_again": @"عرض صفحة الترحيب مرة أخرى",
        @"wn_footnote_welcome": @"مجاني ومفتوح المصدر، وغير تابع لانستقرام — هم أصلًا لا يعلمون بوجودنا.",
        @"wn_footnote_update": @"لم تُضَف أي إعلانات أثناء إعداد هذا التحديث.",

        // مركز التنزيلات
        @"dl_center_title": @"مركز التنزيلات",
        @"dl_center_sub": @"الطابور والتقدّم وسجل كل التنزيلات",
        @"dl_section_active": @"جارية",
        @"dl_section_history": @"السجل",
        @"dl_total_footer": @"إجمالي ما تم تنزيله: %@",
        @"dl_search_placeholder": @"ابحث في التنزيلات",
        @"dl_scope_all": @"الكل",
        @"dl_kind_photo": @"صورة",
        @"dl_kind_video": @"فيديو",
        @"dl_kind_audio": @"صوت",
        @"dl_kind_file": @"ملف",
        @"dl_state_queued": @"في الانتظار…",
        @"dl_state_paused": @"متوقّف مؤقتًا",
        @"dl_state_failed": @"فشل",
        @"dl_state_cancelled": @"أُلغي",
        @"dl_size_of": @"%@ من %@",
        @"dl_pause": @"إيقاف مؤقت",
        @"dl_resume": @"استئناف",
        @"dl_retry": @"إعادة المحاولة",
        @"dl_cancel": @"إلغاء",
        @"dl_pause_all": @"إيقاف الكل",
        @"dl_resume_all": @"استئناف الكل",
        @"dl_clear_history": @"مسح السجل",
        @"dl_clear_history_message": @"يزيل كل التنزيلات المنتهية من القائمة. لن تُحذف الملفات المحفوظة.",
        @"dl_share": @"مشاركة",
        @"dl_copy_link": @"نسخ الرابط",
        @"dl_remove": @"إزالة",
        @"dl_sort_title": @"الترتيب حسب",
        @"dl_sort_newest": @"الأحدث أولًا",
        @"dl_sort_oldest": @"الأقدم أولًا",
        @"dl_sort_name": @"الاسم",
        @"dl_sort_size": @"الحجم",
        @"dl_empty_title": @"لا توجد تنزيلات بعد",
        @"dl_empty_sub": @"ستظهر هنا الوسائط التي تحفظها، مع التقدّم والسجل.",
        @"dl_use_queue_title": @"استخدام طابور التنزيل",
        @"dl_use_queue_sub": @"تعمل التنزيلات في الخلفية وتستمر عند مغادرة التطبيق",
        @"dl_max_concurrent_title": @"عدد التنزيلات المتزامنة",
        @"dl_clear_title": @"الحذف بعد الحفظ",
        @"dl_clear_sub": @"يزيل التنزيل من هذه القائمة بعد حفظه في الصور، فلا يُخزَّن مرتين",
        @"dl_added_to_queue": @"أُضيف إلى الطابور",
        @"dl_already_downloaded": @"تم تنزيله مسبقًا",

        // عناوين صفحات المزايا
        @"page_general": @"عام",
        @"page_feed": @"الصفحة الرئيسية",
        @"page_reels": @"الريلز",
        @"page_stories_messages": @"القصص والرسائل",
        @"page_navigation": @"شريط التنقل",
        @"page_confirmations": @"تأكيد الإجراءات",

        @"inline_download_title": @"زر تحميل مدمج",
        @"inline_download_sub": @"يضيف أيقونة تنزيل في شريط أزرار المنشور بجانب زر الحفظ",
        @"loading": @"جارٍ التحميل",
        @"cancel": @"إلغاء",
    };
}

@end
