#import "SCILocalize.h"

///
/// Every user-facing string this tweak owns, in both languages.
///
/// Short, because almost everything a person reads about this tweak is drawn by Albrhi Panel and
/// lives in the panel's own tables. What is here is what SpringBoard itself might have to say.
///
static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{

        // Shown on the watch's own Software Update page while the hold is on. iOS says the watch
        // is up to date, because that is what it was told; this says who told it.
        @"hold_notice": @"Albrhi Watch is holding watchOS 26 and newer. This page shows no update "
                        @"because Albrhi withheld it, not because none was published — older "
                        @"updates are still offered. Turn the hold off in Settings › "
                        @"Albrhi Watch to see it again.",

        // The install row's own label once it has been disabled. Short: it replaces a button
        // title, not a paragraph.
        @"hold_button": @"Held by Albrhi Watch",
        @"watch_answers_footer": @"Three separate answers, so a watch that pairs but misbehaves can have one of them turned off instead of the whole tweak. These take effect immediately; the master switch above needs a respring.",
        @"watch_answers_section": @"What it answers",
        @"watch_apps": @"Companion app installation",
        @"watch_capabilities": @"Watch capabilities",
        @"watch_credit": @"The pairing core is watched by 34306 (github.com/34306/watched), used under the MIT licence, whose text ships with the package. Albrhi adds the switches, this page and the diagnostics.",
        @"watch_gate_off": @"OFF — nothing below is active. No pairing answers, no update hold, and the diagnostics report will say the same.",
        @"watch_gate_on": @"ON — the answers are installed the next time each process starts.",
        @"watch_hold_updates": @"Hold watchOS updates",
        @"watch_master": @"Enabled",
        @"watch_master_footer": @"iOS refuses to pair with a watch whose watchOS is newer than it expects, and refuses to install companion apps onto it. This answers those questions the way a supported pairing would. It is off until you turn it on, and the answers are only installed while SpringBoard is starting — so respring after changing this.",
        @"watch_nano_probe": @"Read the watch's domains",
        @"watch_page_subtitle": @"Pair a watch running a watchOS this iPhone does not expect.",
        @"watch_pairing": @"Pairing compatibility",
        @"watch_report_copied": @"Report copied",
        @"watch_report_copy": @"Copy the report",
        @"watch_report_empty": @"Nothing yet. Turn the tweak on, restart SpringBoard, open the Watch app once, then come back.",
        @"watch_report_footer": @"What the tweak found inside SpringBoard and the Watch app: which classes are present on your build and what their methods really look like. Send this when something does not work — it is what the next fix is written from.",
        @"watch_report_section": @"Report",
        @"watch_respring": @"Restart SpringBoard",
        @"watch_respring_confirm": @"The screen will go black for a few seconds. Nothing is lost.",
        @"watch_respring_failed": @"This build of iOS does not offer the restart interface. Reboot the phone instead.",
        @"watch_restart_app": @"Restart the Watch app",
        @"watch_restart_footer": @"A full userspace restart is what actually applies a pairing change — measured on a device: the same build refused after a respring and worked once userspace came back. The limits are written once by SpringBoard, and every other process reads them when it next starts, so the Watch app and the daemons keep their old answer until they restart too. Use your jailbreak app for that. These two buttons are the lesser version: reload SpringBoard, or reload the Watch app where the update hold lives.",
        @"watch_restart_section": @"After changing the master switch",
        @"watch_state_off": @"Off",
        @"watch_state_on": @"On",
        @"watch_title": @"Albrhi Watch",
        @"watch_updates_footer": @"Holds watchOS 26 and newer. The version is read from the update itself (SUBDescriptor -productVersion), so older updates — security fixes for the watchOS the watch is on — are still offered. An update whose version cannot be read is let through, because a hold that fires when it cannot tell what it is holding is not a filter. Reopen the Watch app for a change to take effect.",
        @"watch_updates_section": @"watchOS updates",
        @"cancel": @"Cancel",
        @"ok": @"OK",
    };

    _arTable = @{

        @"hold_notice": @"البرهي للساعة يمنع watchOS 26 وما بعده. هذه الصفحة لا تُظهر تحديثاً لأن "
                        @"البرهي حجبه، لا لأنه غير موجود — والتحديثات الأقدم ما تزال تُعرض. "
                        @"أطفئ المنع من الإعدادات › البرهي للساعة لتراه.",

        @"hold_button": @"محجوب — البرهي للساعة",
        @"watch_answers_footer": @"ثلاث إجابات منفصلة، فساعةٌ تقترن ثم تسيء التصرّف يمكن إطفاء واحدة منها بدل الأداة كلها. هذه تأخذ مفعولها فوراً؛ المفتاح الرئيسي أعلاه يحتاج إعادة تشغيل.",
        @"watch_answers_section": @"ما الذي تجيبه",
        @"watch_apps": @"تثبيت التطبيقات المرافقة",
        @"watch_capabilities": @"قدرات الساعة",
        @"watch_credit": @"نواة الاقتران من watched لـ34306 (github.com/34306/watched)، مستعملة تحت رخصة MIT ونصّها يُشحن مع الحزمة. والبرهي يضيف المفاتيح وهذه الصفحة والتشخيص.",
        @"watch_gate_off": @"مطفأة — لا شيء تحتها يعمل. لا إجابات اقتران، ولا منع تحديث، والتقرير سيقول الشيء نفسه.",
        @"watch_gate_on": @"مُفعَّلة — تُركَّب الإجابات عند الإقلاع التالي لكل عملية.",
        @"watch_hold_updates": @"إيقاف تحديثات watchOS",
        @"watch_master": @"مُفعَّل",
        @"watch_master_footer": @"يرفض iOS الاقتران بساعة نظامها أحدث مما يتوقّع، ويرفض تثبيت التطبيقات المرافقة عليها. هذه تجيب تلك الأسئلة كما يجيبها اقترانٌ مدعوم. مطفأة حتى تشغّلها، والإجابات لا تُركَّب إلا أثناء إقلاع SpringBoard — فأعد تشغيله بعد تغيير هذا المفتاح.",
        @"watch_nano_probe": @"اقرأ نطاقات الساعة",
        @"watch_page_subtitle": @"اقترانٌ بساعة نظامها أحدث مما يتوقّعه هذا الآيفون.",
        @"watch_pairing": @"توافق الاقتران",
        @"watch_report_copied": @"نُسخ التقرير",
        @"watch_report_copy": @"انسخ التقرير",
        @"watch_report_empty": @"لا شيء بعد. شغّل الأداة، أعد تشغيل SpringBoard، افتح تطبيق Watch مرة، ثم عد.",
        @"watch_report_footer": @"ما وجدته الأداة داخل SpringBoard وتطبيق Watch: أيّ الأصناف موجودة في نظامك، وكيف تبدو دوالها فعلاً. أرسله حين لا يعمل شيء — منه يُكتب الإصلاح التالي.",
        @"watch_report_section": @"التقرير",
        @"watch_respring": @"إعادة تشغيل SpringBoard",
        @"watch_respring_confirm": @"ستسودّ الشاشة ثوانيَ معدودة. لا يضيع شيء.",
        @"watch_respring_failed": @"هذا الإصدار من iOS لا يوفّر واجهة إعادة التشغيل. أعد تشغيل الهاتف بدلاً من ذلك.",
        @"watch_restart_app": @"إعادة تشغيل تطبيق Watch",
        @"watch_restart_footer": @"إعادة تشغيل يوزرسبيس الكاملة هي التي تُفعّل تغيير الاقتران فعلاً — قيست على جهاز: نفس البناء رفض بعد respring وعمل بعد عودة يوزرسبيس. فالحدود يكتبها SpringBoard مرة، وكل عملية أخرى تقرؤها عند إقلاعها التالي — فيبقى تطبيق Watch والخدمات على جوابهم القديم حتى يُعادوا. استعمل تطبيق الجيلبريك لذلك. وهذان الزران هما النسخة الأصغر: إعادة SpringBoard، أو إعادة تطبيق Watch حيث يسكن منع التحديث.",
        @"watch_restart_section": @"بعد تغيير المفتاح الرئيسي",
        @"watch_state_off": @"مطفأة",
        @"watch_state_on": @"مفعّلة",
        @"watch_title": @"البرهي للساعة",
        @"watch_updates_footer": @"يمنع watchOS 26 وما بعده. ويُقرأ الإصدار من التحديث نفسه (SUBDescriptor -productVersion)، فالتحديثات الأقدم — إصلاحات الأمان لنسخة الساعة الحالية — تبقى معروضة. وأي تحديثٍ لا يُقرأ إصداره يُمرَّر، لأن منعاً يعمل وهو لا يعرف ماذا يمنع ليس ترشيحاً. أعد فتح تطبيق Watch ليأخذ مفعوله.",
        @"watch_updates_section": @"تحديثات watchOS",
        @"cancel": @"إلغاء",
        @"ok": @"حسناً",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    BOOL arabic = [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"];
    NSString *value = arabic ? _arTable[key] : _enTable[key];
    return value ?: (_enTable[key] ?: key);
}
