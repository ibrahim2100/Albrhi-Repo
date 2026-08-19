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
        @"versions_not_installed": @"Not installed on this device",
        @"about_version_panel": @"panel %@",
        @"respring": @"Respring",
        @"respring_confirm": @"The home screen will restart. Nothing is lost — apps you have open will close.",
        @"respring_note": @"Restarts the home screen, which is what makes a newly installed or updated tweak take effect everywhere.",
        @"respring_failed": @"This device would not take the request. Hold the power and volume buttons to restart instead.",
        @"cancel": @"Cancel",
        @"about_signature": @"Albrhi — made by Ibrahim Ismail AL-Rahn.\nFree and open source under the GNU GPL v3. The Instagram tweak is a derivative of SCInsta by SoCuul, whose authorship is credited and preserved.",
        @"apps_footer": @"Albrhi patches nothing until you switch it on here. Your choice is remembered across updates, and turning an app off keeps its settings. Under each name is the app version on this phone and the one that tweak was last verified against — a newer app usually still works, and this is here so you can see the difference when something does not.",
        @"apps_none": @"No Albrhi tweak is installed",
        @"switch_restart": @"Close and reopen the app for this to take effect.",
        @"ok": @"OK",
        @"section_about": @"About",
        @"about_version": @"Version",
        @"about_author": @"Made by",
        @"about_author_name": @"Ibrahim Ismail AL-Rahn",
        @"about_note": @"A greyed switch means that app is not installed on this device.",
        @"section_tweaks": @"Tweaks",
        @"tweaks_footer": @"These run across several processes rather than patching one app, so each has a page of its own. Their switches live inside those pages, not here.",
        @"watch_title": @"Albrhi Watch",
        @"watch_page_subtitle": @"Pair a watch running a watchOS this iPhone does not expect.",
        @"watch_state_on": @"On",
        @"watch_state_off": @"Off",
        @"watch_master": @"Enabled",
        @"watch_master_footer": @"iOS refuses to pair with a watch whose watchOS is newer than it expects, and refuses to install companion apps onto it. This answers those questions the way a supported pairing would. It is off until you turn it on, and the answers are only installed while SpringBoard is starting — so respring after changing this.",
        @"watch_answers_section": @"What it answers",
        @"watch_answers_footer": @"Three separate answers, so a watch that pairs but misbehaves can have one of them turned off instead of the whole tweak. These take effect immediately; the master switch above needs a respring.",
        @"watch_pairing": @"Pairing compatibility",
        @"watch_capabilities": @"Watch capabilities",
        @"watch_apps": @"Companion app installation",
        @"watch_restart_section": @"After changing the master switch",
        @"watch_restart_footer": @"The answers are installed while SpringBoard starts, so turning the tweak on or off does nothing until it restarts. This restarts it — your apps keep running and nothing is lost, the screen goes black for a few seconds.",
        @"watch_respring": @"Restart SpringBoard",
        @"watch_respring_confirm": @"The screen will go black for a few seconds. Nothing is lost.",
        @"watch_respring_failed": @"This build of iOS does not offer the restart interface. Reboot the phone instead.",
        @"watch_credit": @"The pairing core is watched by 34306 (github.com/34306/watched), used under the MIT licence, whose text ships with the package. Albrhi adds the switches, this page and the diagnostics.",
        @"nextup_title": @"Albrhi NextUp",
        @"nextup_page_subtitle": @"What plays next, under the now-playing controls.",
        @"nextup_state_on": @"On",
        @"nextup_state_off": @"Off",
        @"nextup_master": @"Enabled",
        @"nextup_master_footer": @"Shows what plays next under the now-playing controls, with a cover you can tap to play it now and a button to skip it. Turn this off and nothing is drawn anywhere.",
        @"nextup_where_section": @"Where it shows",
        @"nextup_where_footer": @"Each surface can be turned off on its own. Changes apply straight away — no respring.",
        @"nextup_lock_screen": @"Lock Screen",
        @"nextup_dynamic_island": @"Dynamic Island",
        @"nextup_control_center": @"Control Center",
        @"nextup_apps_section": @"Apps",
        @"nextup_apps_footer": @"Each app is read through its own playback queue, so the row shows what that app itself would play next. An app you turn off here is simply never read. Reopen the app for its switch to take effect.\n\nYouTube is the one that behaves differently: a playlist or mix has a real queue, but a standalone video has none, so the row shows YouTube's own autoplay suggestion instead — that one can be played, not skipped or re-ordered, and its cover is 16:9 rather than square.\n\nEach version above is the app build this was written against. A newer app usually still works; when a row goes blank after an update, that number is the first thing to check.",
        @"nextup_support_music": @"Full support",
        @"nextup_support_podcasts": @"Full support",
        @"nextup_support_youtube": @"Full support · built against 21.32.4",
        @"nextup_support_youtube_music": @"Full support · built against 9.28.4",
        @"nextup_support_spotify": @"Full support · built against 9.1.62",
        @"nextup_app_music": @"Music",
        @"nextup_app_podcasts": @"Podcasts",
        @"nextup_app_youtube": @"YouTube",
        @"nextup_app_youtube_music": @"YouTube Music",
        @"nextup_app_spotify": @"Spotify",
        @"nextup_advanced_section": @"Advanced",
        @"nextup_log": @"Diagnostic log",
        @"nextup_log_footer": @"Off. Turn it on only while something is wrong: it writes what each process is doing — including the titles of what is playing — to /var/mobile/nu/. Reopen the app or respring for it to take effect, and turn it off again afterwards.",
        @"nextup_credit": @"Albrhi NextUp is a port of NextUp 3 by Yves (github.com/Yves000/NextUp3), used under the GNU GPL v3. The design and nearly all of the implementation are his work; this port replaced the settings pane and rebranded the package.",

        @"verbose_logging": @"Verbose logging",
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
        @"versions_not_installed": @"غير مثبَّت على هذا الجهاز",
        @"about_version_panel": @"اللوحة %@",
        @"respring": @"إعادة تشغيل الواجهة",
        @"respring_confirm": @"ستُعاد شاشة البداية. لا يضيع شيء — لكن التطبيقات المفتوحة ستُغلق.",
        @"respring_note": @"يعيد تشغيل شاشة البداية، وهو ما يجعل أداة ثُبِّتت أو حُدِّثت للتو تسري في كل مكان.",
        @"respring_failed": @"لم يقبل الجهاز الطلب. أعد التشغيل بزرّي الطاقة ومستوى الصوت بدلاً من ذلك.",
        @"cancel": @"إلغاء",
        @"about_signature": @"البرهي — تطوير إبراهيم إسماعيل الرهن.\nحر ومفتوح المصدر تحت رخصة GNU GPL v3. أداة إنستغرام مشتقّة من SCInsta لـ SoCuul، ونسبتها إليه محفوظة ومذكورة.",
        @"apps_footer": @"لا يعدّل البرهي شيئًا حتى تُشغّله من هنا. اختيارك محفوظ عبر التحديثات، وإيقاف تطبيق يحتفظ بإعداداته. تحت كل اسم إصدار التطبيق على هذا الجهاز والإصدار الذي جُرِّبت عليه الأداة آخر مرة — الأحدث يعمل غالبًا، وهذا ليظهر لك الفرق حين لا يعمل.",
        @"apps_none": @"لا توجد أداة برهي مثبَّتة",
        @"switch_restart": @"أغلق التطبيق وافتحه ليسري المفعول.",
        @"ok": @"حسناً",
        @"section_about": @"عن اللوحة",
        @"about_version": @"الإصدار",
        @"about_author": @"تطوير",
        @"about_author_name": @"إبراهيم إسماعيل الرهن",
        @"about_note": @"المفتاح الرمادي يعني أن ذلك التطبيق غير مثبَّت على هذا الجهاز.",
        @"section_tweaks": @"الأدوات",
        @"tweaks_footer": @"هذه تعمل عبر عدة عمليات بدل تعديل تطبيق واحد، فلكل واحدة صفحتها. مفاتيحها داخل تلك الصفحات لا هنا.",
        @"watch_title": @"البرهي للساعة",
        @"watch_page_subtitle": @"اقترانٌ بساعة نظامها أحدث مما يتوقّعه هذا الآيفون.",
        @"watch_state_on": @"مفعّلة",
        @"watch_state_off": @"مطفأة",
        @"watch_master": @"مُفعَّل",
        @"watch_master_footer": @"يرفض iOS الاقتران بساعة نظامها أحدث مما يتوقّع، ويرفض تثبيت التطبيقات المرافقة عليها. هذه تجيب تلك الأسئلة كما يجيبها اقترانٌ مدعوم. مطفأة حتى تشغّلها، والإجابات لا تُركَّب إلا أثناء إقلاع SpringBoard — فأعد تشغيله بعد تغيير هذا المفتاح.",
        @"watch_answers_section": @"ما الذي تجيبه",
        @"watch_answers_footer": @"ثلاث إجابات منفصلة، فساعةٌ تقترن ثم تسيء التصرّف يمكن إطفاء واحدة منها بدل الأداة كلها. هذه تأخذ مفعولها فوراً؛ المفتاح الرئيسي أعلاه يحتاج إعادة تشغيل.",
        @"watch_pairing": @"توافق الاقتران",
        @"watch_capabilities": @"قدرات الساعة",
        @"watch_apps": @"تثبيت التطبيقات المرافقة",
        @"watch_restart_section": @"بعد تغيير المفتاح الرئيسي",
        @"watch_restart_footer": @"تُركَّب الإجابات أثناء إقلاع SpringBoard، فتشغيل الأداة أو إطفاؤها لا يفعل شيئاً حتى يُعاد تشغيله. هذا الزر يعيد تشغيله — تطبيقاتك تبقى ولا يضيع شيء، وتسودّ الشاشة ثوانيَ معدودة.",
        @"watch_respring": @"إعادة تشغيل SpringBoard",
        @"watch_respring_confirm": @"ستسودّ الشاشة ثوانيَ معدودة. لا يضيع شيء.",
        @"watch_respring_failed": @"هذا الإصدار من iOS لا يوفّر واجهة إعادة التشغيل. أعد تشغيل الهاتف بدلاً من ذلك.",
        @"watch_credit": @"نواة الاقتران من watched لـ34306 (github.com/34306/watched)، مستعملة تحت رخصة MIT ونصّها يُشحن مع الحزمة. والبرهي يضيف المفاتيح وهذه الصفحة والتشخيص.",
        @"nextup_title": @"البرهي نكست أب",
        @"nextup_page_subtitle": @"ما سيُشغَّل بعد قليل، تحت أزرار التشغيل.",
        @"nextup_state_on": @"مُفعَّل",
        @"nextup_state_off": @"مُطفأ",
        @"nextup_master": @"مُفعَّل",
        @"nextup_master_footer": @"يعرض ما سيُشغَّل تالياً أسفل أزرار التشغيل، مع غلاف تضغطه ليُشغَّل الآن وزر لتخطّيه. أوقفه ولن يُرسم شيء في أي مكان.",
        @"nextup_where_section": @"أين يظهر",
        @"nextup_where_footer": @"كل واجهة يمكن إيقافها وحدها. التغييرات تسري فوراً — بلا إعادة تشغيل للواجهة.",
        @"nextup_lock_screen": @"شاشة القفل",
        @"nextup_dynamic_island": @"الجزيرة الديناميكية",
        @"nextup_control_center": @"مركز التحكم",
        @"nextup_apps_section": @"التطبيقات",
        @"nextup_apps_footer": @"كل تطبيق يُقرأ من قائمة تشغيله الخاصة، فالصف يعرض ما سيشغّله التطبيق نفسه بعد قليل. والتطبيق الذي تطفئه هنا لا يُقرأ أصلاً. أعد فتح التطبيق ليأخذ مفتاحه مفعوله.\n\nويوتيوب هو المختلف: قائمة التشغيل أو الميكس لها طابور حقيقي، أما الفيديو المفرد فلا طابور له — فيُعرض اقتراح التشغيل التلقائي من يوتيوب بدلاً منه، وهذا يمكن تشغيله فقط لا تخطّيه ولا إعادة ترتيبه، وغلافه بنسبة 16:9 لا مربّع.\n\nوكل إصدار أعلاه هو بناء التطبيق الذي كُتبت عليه الأداة. الأحدث يعمل غالباً؛ وحين يفرغ الصف بعد تحديث، فهذا الرقم أول ما يُراجَع.",
        @"nextup_support_music": @"دعم كامل",
        @"nextup_support_podcasts": @"دعم كامل",
        @"nextup_support_youtube": @"دعم كامل · مبنية على 21.32.4",
        @"nextup_support_youtube_music": @"دعم كامل · مبنية على 9.28.4",
        @"nextup_support_spotify": @"دعم كامل · مبنية على 9.1.62",
        @"nextup_app_music": @"الموسيقى",
        @"nextup_app_podcasts": @"البودكاست",
        @"nextup_app_youtube": @"يوتيوب",
        @"nextup_app_youtube_music": @"يوتيوب ميوزك",
        @"nextup_app_spotify": @"سبوتيفاي",
        @"nextup_advanced_section": @"متقدّم",
        @"nextup_log": @"سجل التشخيص",
        @"nextup_log_footer": @"مطفأ. شغّله فقط حين يوجد خلل: يكتب ما تفعله كل عملية — ومنه عناوين ما يُشغَّل — في /var/mobile/nu/. أعد فتح التطبيق أو أعد التشغيل ليأخذ مفعوله، ثم أطفئه بعدها.",
        @"nextup_credit": @"البرهي نكست أب نقلٌ لأداة NextUp 3 من Yves ‏(github.com/Yves000/NextUp3)، مستخدمة بموجب رخصة GNU GPL v3. التصميم وأغلب التنفيذ عمله هو؛ وهذا النقل استبدل صفحة الإعدادات وأعاد تسمية الحزمة.",

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
