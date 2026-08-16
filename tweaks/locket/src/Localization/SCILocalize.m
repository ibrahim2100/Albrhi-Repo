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
        @"title": @"Albrhi for Locket",
        @"done": @"Done",

        @"welcome_title": @"Albrhi for Locket",
        @"welcome_body": @"Hides the jailbreak from Locket’s own checks, so a modified phone answers exactly like an ordinary one. And it saves a friend’s moment — the full photo or video they actually sent, not a screenshot.",
        @"welcome_gesture": @"Hold two fingers anywhere in Locket to open it.",
        @"welcome_go": @"Got it",

        @"section_status": @"Status",
        @"status_gate": @"Albrhi in Locket",
        @"gate_on": @"On",
        @"gate_off": @"Off — turn it on in Settings › Albrhi",
        @"status_bypass": @"Hiding the jailbreak",
        @"bypass_on": @"On",
        @"bypass_off": @"Off",
        @"status_total": @"Checks answered",

        @"section_media": @"Save a moment",
        @"media_footer": @"Every moment Locket has loaded since you opened it, newest first. Tap one to save it to Photos. It saves the photo or video a friend actually sent — the full one, not a screenshot.",
        @"media_empty": @"Nothing yet. Open a friend’s moment in Locket and come back.",
        @"media_clear": @"Clear the list",
        @"save_working": @"Saving…",
        @"save_done": @"Saved to Photos",
        @"save_failed": @"Could not save this one.",
        @"save_no_permission": @"Locket needs permission to add to Photos. Settings › Locket › Photos.",

        @"section_kinds": @"What was answered",
        @"kinds_footer": @"Each time Locket or one of its libraries asked the system a question a jailbreak check asks, it was answered as an ordinary phone would answer. This is the running count since you opened the app.",
        @"kinds_empty": @"Nothing asked yet. That is normal early — the checks tend to run a moment after launch and again in the background.",
        @"kind_file": @"File and folder checks",
        @"kind_scheme": @"App-presence checks",
        @"kind_env": @"Injected-library checks",
        @"kind_onesignal": @"OneSignal’s own check",

        @"section_recent": @"Recent",

        @"section_about": @"About",
        @"about_note": @"This only hides the jailbreak from Locket’s checks. It does not touch payments or anything you would pay for.",
        @"credit": @"Albrhi — made by Ibrahim Ismail AL-Rahn. Free and open source under the GNU GPL v3.",
    };

    _arTable = @{
        @"title": @"البرهي للوكِت",
        @"done": @"تم",

        @"welcome_title": @"البرهي للوكِت",
        @"welcome_body": @"يُخفي الجيلبريك عن فحوص لوكِت الخاصة، فيجيب الهاتف المعدَّل تماماً كما يجيب هاتف عادي. ويحفظ لحظة أرسلها صديق — الصورة أو الفيديو الكامل الذي أرسله فعلاً، لا لقطة شاشة.",
        @"welcome_gesture": @"اضغط بإصبعين في أي مكان داخل لوكِت لفتحه.",
        @"welcome_go": @"فهمت",

        @"section_status": @"الحالة",
        @"status_gate": @"البرهي داخل لوكِت",
        @"gate_on": @"مُفعّل",
        @"gate_off": @"مُطفأ — فعّله من الإعدادات › البرهي",
        @"status_bypass": @"إخفاء الجيلبريك",
        @"bypass_on": @"مُفعّل",
        @"bypass_off": @"مُطفأ",
        @"status_total": @"الفحوص المُجاب عنها",

        @"section_media": @"حفظ لحظة",
        @"media_footer": @"كل لحظة حمّلها لوكِت منذ فتحته، الأحدث أولاً. اضغط على واحدة لحفظها في الصور. تُحفظ الصورة أو الفيديو الذي أرسله صديقك فعلاً — الكاملة، لا لقطة شاشة.",
        @"media_empty": @"لا شيء بعد. افتح لحظة صديق في لوكِت ثم ارجع.",
        @"media_clear": @"مسح القائمة",
        @"save_working": @"جارٍ الحفظ…",
        @"save_done": @"حُفظ في الصور",
        @"save_failed": @"تعذّر حفظ هذه.",
        @"save_no_permission": @"يحتاج لوكِت إذناً بالإضافة إلى الصور. الإعدادات › Locket › الصور.",

        @"section_kinds": @"ما الذي أُجيب عنه",
        @"kinds_footer": @"في كل مرة سأل فيها لوكِت أو إحدى مكتباته النظامَ سؤالاً يسأله فحص الجيلبريك، أُجيب كما يُجيب هاتف عادي. هذا العدّ منذ فتحت التطبيق.",
        @"kinds_empty": @"لم يُسأل شيء بعد. هذا طبيعي في البداية — تبدأ الفحوص عادةً بعد الفتح بلحظة ثم في الخلفية.",
        @"kind_file": @"فحوص الملفات والمجلدات",
        @"kind_scheme": @"فحوص وجود التطبيقات",
        @"kind_env": @"فحوص المكتبات المحقونة",
        @"kind_onesignal": @"فحص OneSignal الخاص",

        @"section_recent": @"الأحدث",

        @"section_about": @"عن الأداة",
        @"about_note": @"هذا يُخفي الجيلبريك عن فحوص لوكِت فقط. ولا يمسّ المدفوعات ولا أي شيء تدفع مقابله.",
        @"credit": @"البرهي — تطوير إبراهيم إسماعيل الرهن. حر ومفتوح المصدر تحت رخصة GNU GPL v3.",
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
