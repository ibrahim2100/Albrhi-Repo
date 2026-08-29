//
//  Tweak.x
//  Albrhi for YouTube Music
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "YTMHooks.h"
#import "Localization/SCILocalize.h"
#import "shared/src/SCIPanelGate.h"

///
/// Albrhi for YouTube Music — advertising refused, background playback left alone.
///
/// **The hooks are YTMusicUltimate's**, carried over under GPLv3: the same licence this repository
/// ships under, which is what makes carrying code over lawful rather than merely possible. See
/// CHANGELOG.md and the notice inside the package.
///
/// **The Premium claim is deliberately not here.** That tweak answers `-isPremiumSubscriber` with
/// YES on six classes, which tells YouTube Music the account is a paying one. This project refused
/// the same shape of thing by name for Locket and again for Spotify, and the reason these two files
/// could be taken while that one could not is a fact rather than a judgement: **neither of them
/// ever asks what the account is.** That was measured in the upstream sources before a line was
/// copied.
///
/// The gate is Albrhi Panel's own per-app switch, which is right here and was wrong for Albrhi
/// Watch: this tweak patches exactly one app, so it takes one row on the app list like Instagram
/// and TikTok, and that row's switch is a question somebody can actually answer.
///
%ctor {
    @autoreleasepool {
        NSLog(@"[AlbrhiYTM] %@ loaded", SCIVersionString);

        if (!SCIPanelAllowsThisApp()) {
            NSLog(@"[AlbrhiYTM] switched off in Albrhi — nothing installed");
            return;
        }

        //
        // **The ported hooks read their own dictionary, and Albrhi writes it.**
        //
        // Upstream keeps its switches in a `YTMUltimate` dictionary inside YouTube Music's own
        // defaults, and every hook asks it before acting. Rather than edit that out of each file --
        // they are kept diffable against upstream on purpose -- the dictionary is composed here
        // from Albrhi's own switch, so there is one decision rather than two.
        //
        // Upstream's constructor, which seeded those keys to 1 whenever they were missing, was
        // removed for the same reason: it turned every feature on at load no matter what anybody
        // had decided. **Two switches for one feature is one switch too many**, and this project
        // has already shipped that mistake once in the Spotify port.
        //
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *settings =
            [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];

        settings[@"YTMUltimateIsEnabled"] = @YES;
        settings[@"noAds"] = @YES;
        settings[@"backgroundPlayback"] = @YES;
        settings[@"playbackRateButton"] = @YES;
        settings[@"seekButtons"] = @YES;
        settings[@"disableAutoRadio"] = @YES;

        //
        // **Off unless asked for, and each for its own reason rather than one blanket default.**
        //
        // SponsorBlock sends the video's id to sponsor.ajay.app, which is a third party learning
        // what is being played -- the same cost tikwm.com carries in the TikTok tweak, where the
        // answer was a switch that is off and a row that says what enabling it does. The OLED
        // theme and the hidden navigation buttons are simply appearance, and changing how somebody's
        // app looks the first time they update is not a default anyone asked for.
        //
        if (!settings[@"sponsorBlock"]) settings[@"sponsorBlock"] = @NO;
        if (!settings[@"oledTheme"]) settings[@"oledTheme"] = @NO;
        if (!settings[@"oledKeyboard"]) settings[@"oledKeyboard"] = @NO;
        if (!settings[@"lowContrast"]) settings[@"lowContrast"] = @NO;
        if (!settings[@"hideHistoryButton"]) settings[@"hideHistoryButton"] = @NO;
        if (!settings[@"hideCastButton"]) settings[@"hideCastButton"] = @NO;
        if (!settings[@"hideFilterButton"]) settings[@"hideFilterButton"] = @NO;

        // Upstream's SponsorBlock constructor seeded these two and was removed with the rest;
        // its values are kept because they are the behaviour, not a preference nobody set.
        if (!settings[@"sbSkipMode"]) settings[@"sbSkipMode"] = @0;
        if (!settings[@"sbDuration"]) settings[@"sbDuration"] = @10;
        if (!settings[@"seekTime"]) settings[@"seekTime"] = @0;

        // Audio by default, which is what a music app is for -- and it is upstream's own default
        // too. Written only when unset, so a choice made in the settings screen survives.
        if (!settings[@"audioVideoMode"]) settings[@"audioVideoMode"] = @0;

        //
        // **The lyrics defaults, which were upstream's own %ctor and are now decided here.**
        //
        // Every value is upstream's except the first: `syncedLyricsEnabled` ships **on**, because
        // it was asked for by name, while upstream leaves it off. What that costs is stated in the
        // package description rather than left to be discovered -- a lyrics feature asks outside
        // services what is playing, and there is no version of it that does not.
        //
        // Translation stays off, and is inert regardless: it needs a key the user supplies.
        //
        settings[@"syncedLyricsEnabled"] = @YES;
        if (!settings[@"lyricsPreferredSource"]) settings[@"lyricsPreferredSource"] = @"auto";
        if (!settings[@"lyricsShowInexact"]) settings[@"lyricsShowInexact"] = @YES;
        if (!settings[@"lyricsRomanization"]) settings[@"lyricsRomanization"] = @YES;
        if (!settings[@"lyricsConvertChinese"]) settings[@"lyricsConvertChinese"] = @"disabled";
        if (!settings[@"lyricsShowTimeCodes"]) settings[@"lyricsShowTimeCodes"] = @NO;
        if (!settings[@"lyricsLineEffect"]) settings[@"lyricsLineEffect"] = @"fancy";
        if (!settings[@"lyricsFontSize"]) settings[@"lyricsFontSize"] = @"small";
        if (!settings[@"lyricsTimingOffsetMs"]) settings[@"lyricsTimingOffsetMs"] = @0;
        if (!settings[@"lyricsTimingOffsetActiveKey"]) settings[@"lyricsTimingOffsetActiveKey"] = @"";
        if (!settings[@"lyricsTimingOffsets"]) settings[@"lyricsTimingOffsets"] = @{};
        if (!settings[@"lyricsDefaultText"]) settings[@"lyricsDefaultText"] = @"\u266a";
        if (!settings[@"lyricsTranslationEnabled"]) settings[@"lyricsTranslationEnabled"] = @NO;
        settings[@"lyricsArtworkOverlayEnabled"] = @NO;

        [defaults setObject:settings forKey:@"YTMUltimate"];

        SCIYTMInstallAdBlock();
        SCIYTMInstallUpsell();
        //
        // **Stood down until a crash log names its cause, and that is a retreat on purpose.**
        //
        // 0.8.0 shipped this screen and this tab and did not crash; every version since has, and
        // two diagnoses of mine were wrong -- the icon hook in 0.8.2 and the private ancestor call
        // in 0.8.3 were both real faults and neither was *the* fault. The only behaviour that
        // separates 0.8.0 from the versions that crash is this hook running on taps it used to
        // skip, so it is the one thing removed while the evidence is fetched.
        //
        // **This project's rule is that a crash is worse than the thing it prevents**, and three
        // installs of a crashing app is already more than that rule allows. The tab, the downloads
        // screen, the player and the upsell hiding all stay -- everything 0.8.0 had.
        //
        // SCIYTMInstallDownload();
        SCIYTMInstallBackground();
        SCIYTMInstallPlaybackRate();
        SCIYTMInstallSeekButtons();
        SCIYTMInstallAutoPlay();
        SCIYTMInstallCast();
        SCIYTMInstallAVSwitching();
        SCIYTMInstallNavBar();
        SCIYTMInstallColours();
        SCIYTMInstallSponsorBlock();
        SCIYTMInstallSyncedLyrics();
        SCIYTMInstallSelectableLyrics();
        SCIYTMInstallSettings();
        SCIYTMInstallOtherSettings();

        NSLog(@"[AlbrhiYTM] sixteen feature groups installed, settings included");
    }
}
