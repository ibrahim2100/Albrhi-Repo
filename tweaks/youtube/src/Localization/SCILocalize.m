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

        @"section_ads": @"Ads",
        @"section_player": @"Player",
        @"section_general": @"General",

        @"identity_attached": @"Everything attached",
        @"identity_partial": @"Some features could not attach",

        @"hide_ads": @"Hide ads",
        @"hide_ads_note": @"Stops the app asking for ads at all, drops promoted rows out of the feed, and refuses ads before, during and inside the video.",

        @"hide_paid_promotion": @"Hide the paid promotion notice",
        @"hide_paid_promotion_note": @"Removes the banner a creator shows when a video is sponsored. Off by default — it is a disclosure.",

        @"background_playback": @"Keep playing in the background",
        @"background_playback_note": @"Audio carries on when you leave the app or lock the screen.",

        @"block_update_nag": @"Silence the update prompt",
        @"block_update_nag_note": @"Stops YouTube asking you to update, which would replace the app and remove this tweak.",

        @"section_sponsorblock": @"SponsorBlock",
        @"sponsorblock": @"Skip sponsored parts",
        @"sponsorblock_note": @"Uses segments other viewers submitted, so paid plugs and intros are jumped over.",
        @"sponsorblock_notice": @"Say what was skipped",
        @"sponsorblock_notice_note": @"A short line at the top naming what was skipped, with an undo.",
        @"sponsorblock_markers": @"Colour the progress bar",
        @"sponsorblock_markers_note": @"Marks each segment on the bar in its SponsorBlock colour, so you can see what is coming.",

        @"sb_categories": @"What to skip",
        @"sb_sponsor": @"Paid sponsor",
        @"sb_sponsor_note": @"A plug the creator was paid for.",
        @"sb_selfpromo": @"Self-promotion",
        @"sb_selfpromo_note": @"The creator's own merchandise, channel or Patreon.",
        @"sb_interaction": @"Like and subscribe",
        @"sb_interaction_note": @"A reminder to subscribe or hit the bell.",
        @"sb_intro": @"Intro",
        @"sb_intro_note": @"Title animations and intermissions with no content.",
        @"sb_outro": @"Endcards",
        @"sb_outro_note": @"Credits and the end screen.",
        @"sb_preview": @"Recap",
        @"sb_preview_note": @"A summary of what is coming, or of an earlier episode.",
        @"sb_filler": @"Tangents",
        @"sb_filler_note": @"Jokes and asides that are not needed to follow along. Aggressive — off by default.",
        @"sb_music_offtopic": @"Non-music parts",
        @"sb_music_offtopic_note": @"In a music video, the parts that are not the music.",

        @"sb_skipped_format": @"Skipped: %@",
        @"sb_undo": @"Undo",

        @"sb_credit": @"Segment data from SponsorBlock (sponsor.ajay.app), licensed CC BY-NC-SA 4.0. Your video is never sent — only the first four characters of its fingerprint, so the server cannot tell which video you are watching.\n\nThe coloured markers are derived from iSponsorBlock by Galactic Dev (GPLv3).",

        @"dl_audio_only": @"Audio only",
        @"dl_why_no_data": @"YouTube has not handed over any stream information for this video yet. Start playing it, then hold again.",
        @"dl_why_no_formats": @"Stream information arrived but it lists no formats. This build may only stream in pieces, which cannot be saved as a file.",
        @"dl_why_no_urls": @"Found %ld formats iOS can play, but not one of them carries a link to fetch. This build streams in pieces instead of serving files, so there is nothing to download yet.",
        @"dl_why_unknown": @"Nothing could be saved, and the reason is not one this page knows. Settings, Diagnostics has the full report.",

        @"dl_asking": @"Asking YouTube for the formats…",
        @"dl_api_no_links": @"YouTube did not return any downloadable formats for this video. It may be private, age restricted, or blocked where you are.",
        @"dl_why_unplayable_api": @"Found %ld formats, all in a codec iOS will not play. Saving one would give you a file that shows a black screen.",

        @"diag_active_video": @"Actually playing",
        @"diag_stream_attempts": @"Asking YouTube for formats",


        @"dl_hls_none": @"No playlist for this video yet. Start it playing, then hold again.",
        @"dl_hls_no_variants": @"The playlist lists no quality iOS can save. Everything in it is in a codec that would download and then not play.",
        @"dl_hls_no_segments": @"The playlist for that quality is empty.",
        @"dl_hls_unreadable": @"The pieces downloaded, but they do not join into a video this device can read. This build serves them in a form that needs converting.",
        @"dl_ts_empty": @"The download finished with nothing in it. Try again.",
        @"dl_ts_no_video": @"The parts arrived, but there is no picture inside them this can convert. Try a different quality.",
        @"dl_ts_write_failed": @"The video was unwrapped but could not be written out. There may be no room left on the device.",
        @"dl_unknown_quality": @"Unknown quality",
        @"dl_progress_format": @"Saving… %d%%",

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

        @"diag_sponsor": @"SponsorBlock",
        @"diag_sponsor_none": @"Nothing yet. Play a video with the feature on, then come back.",
        @"diag_sponsor_no_id": @"Could not read a video ID from %@ — no segments were requested.",
        @"diag_sponsor_segments": @"%@: %lu segments matched your categories.",
        @"diag_sponsor_skipped": @"Skipped %@ (%.1fs to %.1fs).",
        @"diag_markers_drawn": @"Markers drawn on %@ (%ld).",
        @"diag_markers_none": @"No progress bar found to draw markers on yet.",

        @"ok": @"OK",

        @"dl_row": @"Save this video",
        @"dl_row_note": @"Downloads the video you are watching to Photos, at the quality you pick.",
        @"dl_title": @"Save video",
        @"dl_choose_quality": @"Which quality?",
        @"dl_with_audio": @" (fetches audio too)",
        @"dl_saving": @"Saving",
        @"dl_working": @"Downloading, then writing to Photos. This stays open until it is done.",
        @"dl_saved": @"Saved to Photos.",

        // The Download Centre.
        @"set_dislikes": @"Show dislike counts",
        @"set_dislikes_note": @"YouTube stopped publishing this number in 2021. It comes from the Return YouTube Dislike archive, which is an estimate from what its users report — not YouTube's own figure. Nothing about what you watch is sent.",
        @"diag_counters": @"Like and dislike buttons found",
        @"section_quality": @"Quality",
        @"set_classic_quality": @"Full quality list",
        @"set_classic_quality_note": @"Show every resolution when you tap quality, instead of the two-line shortcut.",
        @"set_cap_wifi": @"Highest on Wi-Fi",
        @"set_cap_cellular": @"Highest on mobile data",
        @"set_cap_note": @"A ceiling, not a fixed quality. YouTube still drops lower when the connection cannot keep up.",
        @"quality_auto": @"No limit",
        @"quality_cap_format": @"Up to %ldp",
        @"dl_centre_title": @"Downloads",
        @"dl_centre_empty": @"Nothing saved yet",
        @"dl_centre_empty_hint": @"Hold a video to save it. What you save stays here — it does not go to Photos unless you send it.",
        @"dl_centre_footer": @"%lu saved · %@",
        @"dl_started": @"Saving. Watch it in Downloads.",
        @"dl_untitled": @"Video",
        @"dl_in_photos": @"in Photos",
        @"dl_to_photos": @"To Photos",
        @"dl_share": @"Share",
        @"delete": @"Delete",
        @"dl_audio_not_photos": @"Photos holds videos and pictures, not sound. Share it instead.",
        @"dl_no_audio_track": @"There is no sound in this one to keep.",

        // Choosing what to save.
        @"dl_choose_title": @"Save",
        @"dl_kind_video": @"Video",
        @"dl_kind_audio": @"Sound",
        @"dl_quality_header": @"Size",
        @"dl_sound_header": @"Sound only",
        @"dl_sound_only": @"Sound only",
        @"dl_sound_small": @"A fraction of the size",

        // Settings.
        @"set_auto_photos": @"Also save to Photos",
        @"set_auto_photos_note": @"Off: downloads stay in the Download Centre and go to Photos only when you send them.",
        @"set_tab_button": @"Button beside You",
        @"set_downloads_title": @"Downloads",
        @"set_open_centre": @"Download Centre",
        @"dl_saved_silent": @"Saved, but without sound — the audio track would not download.",
        @"dl_failed": @"That did not work. The diagnostics page has the detail.",
        @"dl_no_permission": @"Photos access was refused, so there is nowhere to save it.",
        @"dl_no_photos_access": @"YouTube itself cannot add to Photos, so the video is being handed to you instead — choose Save Video.",
        @"dl_diag_none": @"No saveable format found.",
        @"dl_diag_found": @"%ld video and %ld audio formats with links.",
        @"diag_downloadable": @"Saveable",
        @"cancel": @"Cancel",
        @"diag_truncated": @"— shown up to here. The rest is in the full report, written to %@ and copied whole by the button below.",
        @"diag_page_failed": @"This page could not be opened, and the report was written to %@ instead.",

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

        @"section_ads": @"الإعلانات",
        @"section_player": @"المشغّل",
        @"section_general": @"عام",

        @"identity_attached": @"كل شيء مرتبط",
        @"identity_partial": @"بعض المميزات لم ترتبط",

        @"hide_ads": @"حجب الإعلانات",
        @"hide_ads_note": @"يمنع التطبيق من طلبها أصلًا، ويُسقط الصفوف المُموّلة من الخصائص، ويرفض الإعلانات قبل الفيديو وأثناءه والمدموجة فيه.",

        @"hide_paid_promotion": @"إخفاء تنبيه الترويج المدفوع",
        @"hide_paid_promotion_note": @"يُزيل الشريط الذي يظهر عندما يكون الفيديو مموّلًا. مطفأ افتراضيًا — لأنه إفصاح.",

        @"background_playback": @"الاستمرار في الخلفية",
        @"background_playback_note": @"يكمل الصوت عند خروجك من التطبيق أو قفل الشاشة.",

        @"block_update_nag": @"كتم تنبيه التحديث",
        @"block_update_nag_note": @"يمنع يوتيوب من مطالبتك بالتحديث، فالتحديث يستبدل التطبيق ويُزيل هذه الأداة.",

        @"section_sponsorblock": @"سبونسر بلوك",
        @"sponsorblock": @"تخطّي المقاطع المموّلة",
        @"sponsorblock_note": @"يستخدم مقاطع أرسلها مشاهدون آخرون، فتُتجاوَز الإعلانات المدفوعة والمقدّمات.",
        @"sponsorblock_notice": @"إظهار ما تم تخطّيه",
        @"sponsorblock_notice_note": @"سطر قصير في الأعلى يسمّي ما تُخطّي، ومعه زر تراجع.",
        @"sponsorblock_markers": @"تلوين شريط التقدّم",
        @"sponsorblock_markers_note": @"يعلّم كل مقطع على الشريط بلون سبونسر بلوك الخاص به، فترى ما هو قادم.",

        @"sb_categories": @"ما الذي يُتخطّى",
        @"sb_sponsor": @"إعلان مدفوع",
        @"sb_sponsor_note": @"ترويج تلقّى صاحب القناة مقابلًا عليه.",
        @"sb_selfpromo": @"ترويج ذاتي",
        @"sb_selfpromo_note": @"منتجات صاحب القناة أو قناته أو دعمه.",
        @"sb_interaction": @"طلب الإعجاب والاشتراك",
        @"sb_interaction_note": @"تذكير بالاشتراك أو تفعيل الجرس.",
        @"sb_intro": @"المقدّمة",
        @"sb_intro_note": @"مقدّمات وحركات العنوان بلا محتوى.",
        @"sb_outro": @"الخاتمة",
        @"sb_outro_note": @"الشكر وشاشة النهاية.",
        @"sb_preview": @"التلخيص",
        @"sb_preview_note": @"ملخّص لما سيأتي، أو لحلقة سابقة.",
        @"sb_filler": @"الاستطراد",
        @"sb_filler_note": @"نكات وجُمل جانبية لا يحتاجها الفهم. حادّ — مطفأ افتراضيًا.",
        @"sb_music_offtopic": @"غير الموسيقى",
        @"sb_music_offtopic_note": @"في المقاطع الغنائية، الأجزاء التي ليست موسيقى.",

        @"sb_skipped_format": @"تم تخطّي: %@",
        @"sb_undo": @"تراجع",

        @"sb_credit": @"بيانات المقاطع من سبونسر بلوك (sponsor.ajay.app) برخصة CC BY-NC-SA 4.0. لا يُرسَل الفيديو الذي تشاهده إطلاقًا — تُرسَل أربعة أحرف من بصمته فقط، فلا يعرف الخادم أيّ فيديو تشاهد.\n\nالعلامات الملوّنة مُشتقّة من iSponsorBlock لـ Galactic Dev (رخصة GPLv3).",

        @"dl_audio_only": @"الصوت فقط",
        @"dl_why_no_data": @"يوتيوب لم يُسلّم بعد أي معلومات عن مقاطع هذا الفيديو. شغّله ثم اضغط مطوّلًا مرة أخرى.",
        @"dl_why_no_formats": @"وصلت معلومات المقاطع لكنها بلا صيغ. قد تكون هذه النسخة تبثّ على أجزاء فقط، وهذا لا يُحفَظ كملف.",
        @"dl_why_no_urls": @"وُجدت %ld صيغة يشغّلها iOS، لكن لا واحدة منها تحمل رابطًا للتحميل. هذه النسخة تبثّ على أجزاء بدل أن تقدّم ملفات، فلا شيء يمكن تحميله بعد.",
        @"dl_why_unknown": @"تعذّر حفظ أي شيء، والسبب ليس مما تعرفه هذه الصفحة. التقرير الكامل في الإعدادات ثم التشخيص.",

        @"dl_asking": @"جارٍ سؤال يوتيوب عن الصيغ…",
        @"dl_api_no_links": @"يوتيوب لم يُرجع أي صيغة قابلة للتحميل لهذا الفيديو. قد يكون خاصًّا أو مقيَّدًا بالعمر أو محجوبًا في بلدك.",
        @"dl_why_unplayable_api": @"وُجدت %ld صيغة، كلها بترميز لا يشغّله iOS. حفظ أيّ منها يعطيك ملفًا بشاشة سوداء.",

        @"diag_active_video": @"المُشغَّل فعلًا",
        @"diag_stream_attempts": @"سؤال يوتيوب عن الصيغ",


        @"dl_hls_none": @"لا توجد قائمة تشغيل لهذا الفيديو بعد. شغّله ثم اضغط مطوّلًا مرة أخرى.",
        @"dl_hls_no_variants": @"القائمة لا تعرض جودة يستطيع iOS حفظها. كل ما فيها بترميز يُحمَّل ثم لا يعمل.",
        @"dl_hls_no_segments": @"قائمة تلك الجودة فارغة.",
        @"dl_hls_unreadable": @"نُزّلت الأجزاء، لكنها لا تجتمع في فيديو يقرأه هذا الجهاز. هذا البناء يقدّمها بصيغة تحتاج تحويلًا.",
        @"dl_ts_empty": @"انتهى التنزيل وليس فيه شيء. جرّب مرة أخرى.",
        @"dl_ts_no_video": @"وصلت الأجزاء، لكن لا توجد بداخلها صورة يمكن تحويلها. جرّب جودة أخرى.",
        @"dl_ts_write_failed": @"فُكَّ غلاف الفيديو لكن تعذّرت كتابته. قد لا تكون هناك مساحة كافية على الجهاز.",
        @"dl_unknown_quality": @"جودة غير معروفة",
        @"dl_progress_format": @"جارٍ الحفظ… %d%%",

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

        @"diag_sponsor": @"سبونسر بلوك",
        @"diag_sponsor_none": @"لا شيء بعد. شغّل فيديو والميزة مفعّلة ثم ارجع.",
        @"diag_sponsor_no_id": @"تعذّرت قراءة معرّف الفيديو من %@ — لم تُطلب أي مقاطع.",
        @"diag_sponsor_segments": @"%@: %lu مقطعًا يطابق فئاتك.",
        @"diag_sponsor_skipped": @"تم تخطّي %@ (من %.1f ث إلى %.1f ث).",
        @"diag_markers_drawn": @"رُسمت العلامات على %@ (%ld).",
        @"diag_markers_none": @"لم يُعثر بعد على شريط تقدّم لرسم العلامات عليه.",

        @"ok": @"حسنًا",

        @"dl_row": @"احفظ هذا الفيديو",
        @"dl_row_note": @"ينزّل الفيديو الذي تشاهده إلى الصور، بالجودة التي تختارها.",
        @"dl_title": @"حفظ الفيديو",
        @"dl_choose_quality": @"أي جودة؟",
        @"dl_with_audio": @" (يجلب الصوت أيضًا)",
        @"dl_saving": @"جارٍ الحفظ",
        @"dl_working": @"يُنزَّل ثم يُكتب في الصور. تبقى هذه النافذة حتى ينتهي.",
        @"dl_saved": @"حُفظ في الصور.",

        // مركز التحميلات.
        @"set_dislikes": @"إظهار عدد عدم الإعجاب",
        @"set_dislikes_note": @"يوتيوب أوقف نشر هذا الرقم عام 2021. يأتي من أرشيف Return YouTube Dislike، وهو تقدير ممّا يبلّغ عنه مستخدموه — لا رقم يوتيوب نفسه. ولا يُرسَل شيء عمّا تشاهده.",
        @"diag_counters": @"أزرار الإعجاب وعدمه الموجودة",
        @"section_quality": @"الجودة",
        @"set_classic_quality": @"قائمة الجودة الكاملة",
        @"set_classic_quality_note": @"إظهار كل الدقّات عند الضغط على الجودة، بدل الاختصار ذي السطرين.",
        @"set_cap_wifi": @"الأعلى على الواي فاي",
        @"set_cap_cellular": @"الأعلى على بيانات الجوال",
        @"set_cap_note": @"سقف لا جودة ثابتة. يوتيوب ينزل أقلّ إن لم يتحمّل الاتصال.",
        @"quality_auto": @"بلا حدّ",
        @"quality_cap_format": @"حتى %ldp",
        @"dl_centre_title": @"التحميلات",
        @"dl_centre_empty": @"لا شيء محفوظ بعد",
        @"dl_centre_empty_hint": @"اضغط مطوّلًا على الفيديو لحفظه. ما تحفظه يبقى هنا — ولا يذهب إلى الصور إلا إذا أرسلته.",
        @"dl_centre_footer": @"%lu محفوظ · %@",
        @"dl_started": @"جارٍ الحفظ. تابعه في التحميلات.",
        @"dl_untitled": @"فيديو",
        @"dl_in_photos": @"في الصور",
        @"dl_to_photos": @"إلى الصور",
        @"dl_share": @"مشاركة",
        @"delete": @"حذف",
        @"dl_audio_not_photos": @"الصور تحفظ الفيديو والصور لا الصوت. شاركه بدل ذلك.",
        @"dl_no_audio_track": @"لا صوت في هذا لحفظه.",

        // اختيار ما يُحفظ.
        @"dl_choose_title": @"حفظ",
        @"dl_kind_video": @"فيديو",
        @"dl_kind_audio": @"صوت",
        @"dl_quality_header": @"الجودة",
        @"dl_sound_header": @"الصوت فقط",
        @"dl_sound_only": @"الصوت فقط",
        @"dl_sound_small": @"جزء يسير من الحجم",

        // الإعدادات.
        @"set_auto_photos": @"احفظ في الصور أيضًا",
        @"set_auto_photos_note": @"مُطفأ: تبقى التحميلات في مركز التحميلات ولا تذهب إلى الصور إلا حين ترسلها.",
        @"set_tab_button": @"زر بجانب «أنت»",
        @"set_downloads_title": @"التحميلات",
        @"set_open_centre": @"مركز التحميلات",
        @"dl_saved_silent": @"حُفظ لكن بلا صوت — تعذّر تنزيل مسار الصوت.",
        @"dl_failed": @"لم ينجح ذلك. التفصيل في صفحة التشخيص.",
        @"dl_no_permission": @"رُفض الوصول إلى الصور، فلا مكان للحفظ فيه.",
        @"dl_no_photos_access": @"يوتيوب نفسه لا يملك إذن الإضافة إلى الصور، لذا سيُسلَّم إليك الفيديو — اختر «حفظ الفيديو».",
        @"dl_diag_none": @"لم يُعثر على صيغة قابلة للحفظ.",
        @"dl_diag_found": @"%ld صيغة فيديو و%ld صيغة صوت بروابط.",
        @"diag_downloadable": @"قابلية الحفظ",
        @"cancel": @"إلغاء",
        @"diag_truncated": @"— يُعرض إلى هنا. البقية في التقرير الكامل، وقد كُتب في %@ ويَنسخه الزر أدناه كاملًا.",
        @"diag_page_failed": @"تعذّر فتح هذه الصفحة، وكُتب التقرير في %@ بدلًا من ذلك.",

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
