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
        @"panel_on_count": @"%ld of %ld on",
        @"panel_tagline": @"One tweak for every app it supports, switched from here.",
        @"section_apps": @"Apps",
        @"section_versions": @"Versions",
        @"versions_footer": @"The app version each tweak was last verified against. A newer app usually still works — this is here so you can see the difference when something does not.",
        @"versions_match": @"%@ · tested",
        @"versions_differ": @"%@ · tested on %@",
        @"versions_tested_only": @"tested on %@",
        @"versions_unknown": @"not known",
        @"about_version_panel": @"panel %@",
        @"respring": @"Respring",
        @"respring_confirm": @"The home screen will restart. Nothing is lost — apps you have open will close.",
        @"respring_note": @"Restarts the home screen, which is what makes a newly installed or updated tweak take effect everywhere.",
        @"respring_failed": @"This device would not take the request. Hold the power and volume buttons to restart instead.",
        @"cancel": @"Cancel",
        @"about_signature": @"Albrhi — made by Ibrahim Ismail AL-Rahn.\nFree and open source under the GNU GPL v3. The Instagram tweak is a derivative of SCInsta by SoCuul, whose authorship is credited and preserved.",
        @"apps_footer": @"Albrhi patches nothing until you switch it on here. Turn on the apps you want; the rest are left exactly as they were. Your choice is remembered across updates, and turning an app off keeps its settings for when you turn it back on.",
        @"apps_none": @"No Albrhi tweak is installed",
        @"switch_restart": @"Close and reopen the app for this to take effect.",
        @"ok": @"OK",
        @"section_about": @"About",
        @"about_version": @"Version",
        @"about_author": @"Made by",
        @"about_author_name": @"Ibrahim Ismail AL-Rahn",
        @"about_note": @"A greyed switch means that app is not installed on this device.",
        @"carplay_title": @"Albrhi CarPlay",
        @"carplay_master": @"Enabled",
        @"carplay_master_footer": @"Turn CarPlay off and neither half of it — the recording-audio fix in Camera, or the screen watcher in SpringBoard — does anything. Close the app that is open for a change to take effect.",
        @"carplay_audio_section": @"Recording audio fix",
        @"carplay_audio_footer": @"Keeps your car's speakers in high quality while Camera is recording, instead of dropping to phone-call quality the moment a microphone is needed too.",
        @"carplay_audio_fix": @"Audio fix enabled",
        @"carplay_mic_section": @"Microphone while recording",
        @"carplay_mic_footer": @"iPhone keeps the car's speakers on their high-quality profile and records with the iPhone's own mic. Car lets iOS use the car's microphone, which drops the speakers to phone-call quality — the behaviour without this tweak. Automatic leaves the session exactly as Camera set it up.",
        @"carplay_mic_iphone": @"iPhone",
        @"carplay_mic_car": @"Car",
        @"carplay_mic_automatic": @"Automatic",
        @"carplay_about_footer": @"Not validated on-device yet — this has been built and checked, but not run in a real car. Diagnostics are written to Documents/AlbrhiCP-report.txt inside whichever app CarPlay last ran in.",
        @"verbose_logging": @"Verbose logging",
        @"carplay_bridge_section": @"Apps on the CarPlay dashboard",
        @"carplay_bridge_footer": @"Bundle identifiers to show their real interface on the CarPlay dashboard instead of a template screen — the exact identifier (com.google.ios.youtube, not \"YouTube\"). Known to work on iOS 16 and 17 only. Respring after changing this list: SpringBoard caches what it already asked about an app, and reopening the app alone is not always enough. Even once it works, an app that has not opted into running two windows at once may end up usable from the car OR the phone, not both at the same time — the same limitation CarBridge has.",
        @"carplay_bridge_count": @"Bridged apps",
        @"carplay_bridge_none": @"None",
        @"carplay_bridge_edit": @"Edit Bridged Apps",
        @"carplay_bridge_edit_message": @"Comma-separated bundle identifiers, such as com.example.app, com.example.other.",
        @"carplay_bridge_respring": @"Saved. Go back to Settings › Albrhi and tap Respring for SpringBoard to actually ask CarPlay about this list again — reopening the app on its own is often not enough.",
        @"carplay_wallpaper_section": @"Dashboard wallpaper",
        @"carplay_wallpaper_footer": @"Replaces the background behind the CarPlay dashboard's app icons with a photo of your own. Found by reading Apple's own hidden CarPlayWallpaper app, not guessed at — not validated on-device yet.",
        @"carplay_wallpaper_status": @"Wallpaper",
        @"carplay_wallpaper_choose": @"Choose Wallpaper Image",
        @"carplay_wallpaper_clear": @"Remove Custom Wallpaper",
        @"carplay_wallpaper_set": @"Custom image set",
        @"carplay_wallpaper_none": @"None — Apple's own wallpaper",
    };

    _arTable = @{
        @"panel_title": @"البرهي",
        @"panel_on_count": @"%ld من %ld مُشغَّل",
        @"panel_tagline": @"أداة واحدة لكل تطبيق تدعمه، تتحكم بها من هنا.",
        @"section_apps": @"التطبيقات",
        @"section_versions": @"الإصدارات",
        @"versions_footer": @"إصدار التطبيق الذي جُرّبت عليه كل أداة آخر مرة. الإصدار الأحدث يعمل غالباً — وهذا القسم ليظهر لك الفرق حين لا يعمل.",
        @"versions_match": @"%@ · مُجرَّب",
        @"versions_differ": @"%@ · جُرِّب على %@",
        @"versions_tested_only": @"جُرِّب على %@",
        @"versions_unknown": @"غير معروف",
        @"about_version_panel": @"اللوحة %@",
        @"respring": @"إعادة تشغيل الواجهة",
        @"respring_confirm": @"ستُعاد شاشة البداية. لا يضيع شيء — لكن التطبيقات المفتوحة ستُغلق.",
        @"respring_note": @"يعيد تشغيل شاشة البداية، وهو ما يجعل أداة ثُبِّتت أو حُدِّثت للتو تسري في كل مكان.",
        @"respring_failed": @"لم يقبل الجهاز الطلب. أعد التشغيل بزرّي الطاقة ومستوى الصوت بدلاً من ذلك.",
        @"cancel": @"إلغاء",
        @"about_signature": @"البرهي — تطوير إبراهيم إسماعيل الرهن.\nحر ومفتوح المصدر تحت رخصة GNU GPL v3. أداة إنستغرام مشتقّة من SCInsta لـ SoCuul، ونسبتها إليه محفوظة ومذكورة.",
        @"apps_footer": @"لا يعدّل البرهي شيئًا حتى تُشغّله من هنا. شغّل التطبيقات التي تريدها، والباقي يبقى كما هو تمامًا. اختيارك محفوظ عبر التحديثات، وإيقاف تطبيق يحتفظ بإعداداته لحين تشغيله ثانية.",
        @"apps_none": @"لا توجد أداة برهي مثبَّتة",
        @"switch_restart": @"أغلق التطبيق وافتحه ليسري المفعول.",
        @"ok": @"حسناً",
        @"section_about": @"عن اللوحة",
        @"about_version": @"الإصدار",
        @"about_author": @"تطوير",
        @"about_author_name": @"إبراهيم إسماعيل الرهن",
        @"about_note": @"المفتاح الرمادي يعني أن ذلك التطبيق غير مثبَّت على هذا الجهاز.",
        @"carplay_title": @"البرهي كاربلي",
        @"carplay_master": @"مُفعَّل",
        @"carplay_master_footer": @"أوقف كاربلي ولن يعمل أي من نصفيه — لا إصلاح صوت التسجيل في الكاميرا، ولا مراقب الشاشة في سبرينق بورد. أغلق التطبيق المفتوح ليسري المفعول.",
        @"carplay_audio_section": @"إصلاح صوت التسجيل",
        @"carplay_audio_footer": @"يبقي سماعات سيارتك بجودة عالية أثناء تسجيل الكاميرا، بدلاً من انخفاضها لجودة مكالمة هاتفية بمجرد الحاجة لمايكروفون أيضاً.",
        @"carplay_audio_fix": @"إصلاح الصوت مُفعَّل",
        @"carplay_mic_section": @"المايكروفون أثناء التسجيل",
        @"carplay_mic_footer": @"آيفون يُبقي سماعات السيارة بجودتها العالية ويسجّل بمايك الآيفون نفسه. سيارة يترك iOS يستخدم مايك السيارة، وهذا يخفّض السماعات لجودة مكالمة هاتفية — وهو السلوك بلا هذه الأداة. تلقائي يترك الجلسة كما ضبطتها الكاميرا تماماً.",
        @"carplay_mic_iphone": @"آيفون",
        @"carplay_mic_car": @"سيارة",
        @"carplay_mic_automatic": @"تلقائي",
        @"carplay_about_footer": @"لم يُختبر على جهاز حقيقي بعد — بُني وفُحص لكن لم يُشغَّل داخل سيارة فعلية. تُكتب تقارير التشخيص في Documents/AlbrhiCP-report.txt داخل أيّ تطبيق شغّل كاربلي آخر مرة.",
        @"verbose_logging": @"سجلّ تفصيلي",
        @"carplay_bridge_section": @"التطبيقات على لوحة كاربلي",
        @"carplay_bridge_footer": @"معرّفات الحزم (bundle identifiers) لعرض واجهتها الحقيقية على لوحة كاربلي بدل شاشة القالب — المعرّف الدقيق (com.google.ios.youtube وليس \"يوتيوب\"). معروف أنه يعمل على iOS 16 و17 فقط. أعد تشغيل الواجهة (Respring) بعد تغيير هذه القائمة: سبرينق بورد يخزّن مؤقتًا ما سبق أن سأل عنه بخصوص التطبيق، وإعادة فتح التطبيق وحدها لا تكفي غالبًا. وحتى عند نجاحها، تطبيق لم يُفعّل دعم نافذتين في آنٍ واحد قد يعمل من السيارة أو من الجوال، وليس الاثنين معًا — نفس قيد CarBridge نفسه.",
        @"carplay_bridge_count": @"التطبيقات المفعّلة",
        @"carplay_bridge_none": @"لا شيء",
        @"carplay_bridge_edit": @"تعديل التطبيقات المفعّلة",
        @"carplay_bridge_edit_message": @"معرّفات الحزم مفصولة بفواصل، مثل com.example.app, com.example.other.",
        @"carplay_bridge_respring": @"تم الحفظ. ارجع إلى Settings › البرهي واضغط \"إعادة تشغيل الواجهة\" ليسأل سبرينق بورد كاربلي فعليًا عن هذه القائمة من جديد — إعادة فتح التطبيق وحده غالبًا لا يكفي.",
        @"carplay_wallpaper_section": @"خلفية لوحة التطبيقات",
        @"carplay_wallpaper_footer": @"تستبدل الخلفية خلف أيقونات لوحة كاربلي بصورة من اختيارك. عُثر عليها بقراءة تطبيق آبل المخفي CarPlayWallpaper نفسه، لا تخمينًا — لم تُختبر على جهاز حقيقي بعد.",
        @"carplay_wallpaper_status": @"الخلفية",
        @"carplay_wallpaper_choose": @"اختيار صورة الخلفية",
        @"carplay_wallpaper_clear": @"إزالة الخلفية المخصّصة",
        @"carplay_wallpaper_set": @"صورة مخصّصة مُعيَّنة",
        @"carplay_wallpaper_none": @"لا شيء — خلفية آبل الافتراضية",
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
