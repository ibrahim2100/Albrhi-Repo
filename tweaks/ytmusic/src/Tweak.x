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

        [defaults setObject:settings forKey:@"YTMUltimate"];

        SCIYTMInstallAdBlock();
        SCIYTMInstallBackground();

        NSLog(@"[AlbrhiYTM] ads and background playback installed");
    }
}
