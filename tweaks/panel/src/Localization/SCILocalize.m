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
        @"versions_unknown": @"not known",
        @"about_version_panel": @"panel %@",
        @"respring": @"Respring",
        @"respring_confirm": @"The home screen will restart. Nothing is lost — apps you have open will close.",
        @"respring_note": @"Restarts the home screen, which is what makes a newly installed or updated tweak take effect everywhere.",
        @"respring_failed": @"This device would not take the request. Hold the power and volume buttons to restart instead.",
        @"cancel": @"Cancel",
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
        @"versions_unknown": @"غير معروف",
        @"about_version_panel": @"اللوحة %@",
        @"respring": @"إعادة تشغيل الواجهة",
        @"respring_confirm": @"ستُعاد شاشة البداية. لا يضيع شيء — لكن التطبيقات المفتوحة ستُغلق.",
        @"respring_note": @"يعيد تشغيل شاشة البداية، وهو ما يجعل أداة ثُبِّتت أو حُدِّثت للتو تسري في كل مكان.",
        @"respring_failed": @"لم يقبل الجهاز الطلب. أعد التشغيل بزرّي الطاقة ومستوى الصوت بدلاً من ذلك.",
        @"cancel": @"إلغاء",
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
