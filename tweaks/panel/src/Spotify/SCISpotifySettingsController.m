//
//  SCISpotifySettingsController.m
//  Albrhi Panel
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCISpotifySettingsController.h"
#import <Preferences/PSSpecifier.h>
#import "../Localization/SCILocalize.h"
#import "shared/src/Prefs/SCIPanelBadge.h"

/// The tweak's own domain, named identically in tweaks/spotify/src/Prefs.swift. Two spellings of
/// this string is a switch that appears to work and changes nothing.
static NSString *const kSCISpotifyDomain = @"com.albrhi.spotify";

typedef struct { __unsafe_unretained NSString *key; BOOL defaultsTo; } SCISpotifyToggle;

/// Every switch, with the default the *tweak* uses for it — stated here rather than inferred,
/// because a page showing a different default than the tweak applies is a screen stating the
/// opposite of what is happening.
static const SCISpotifyToggle kSCISpotifyToggles[] = {
    { @"spotify_enabled",      NO  },
    { @"spotify_block_ads",    YES },
    { @"spotify_block_upsell", YES },
    // Off: it asks a third-party server about what is playing, and that cost is paid only by
    // somebody who chose it -- the same rule the TikTok tweak's external download switch follows.
    { @"spotify_sponsorblock",  NO  },
};

static const size_t kSCISpotifyToggleCount =
    sizeof(kSCISpotifyToggles) / sizeof(kSCISpotifyToggles[0]);

@implementation SCISpotifySettingsController

- (BOOL)sci_readBool:(NSString *)key {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCISpotifyDomain);

    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)kSCISpotifyDomain);
    if (value) {
        BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
            ? CFBooleanGetValue((CFBooleanRef)value) : NO;
        CFRelease(value);
        return result;
    }

    for (size_t i = 0; i < kSCISpotifyToggleCount; i++) {
        if ([key isEqualToString:kSCISpotifyToggles[i].key]) return kSCISpotifyToggles[i].defaultsTo;
    }
    return NO;
}

- (id)spotifyValueForSpecifier:(PSSpecifier *)specifier {
    return @([self sci_readBool:[specifier propertyForKey:@"sciSpotifyKey"]]);
}

- (void)setSpotifyValue:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciSpotifyKey"];
    if (!key.length) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value.boolValue),
                             (__bridge CFStringRef)kSCISpotifyDomain);
    // Written through immediately: left to cfprefsd's own schedule, an app relaunched seconds
    // later reads the old value and the switch looks broken for the one action it exists to be
    // followed by.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCISpotifyDomain);

    if ([key isEqualToString:@"spotify_enabled"]) [self reloadSpecifiers];
}

- (PSSpecifier *)spotifyGroupTitled:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:(title ?: @"")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

- (PSSpecifier *)spotifySwitchTitled:(NSString *)title
                                 key:(NSString *)key
                              symbol:(NSString *)symbol
                                tint:(UIColor *)tint {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:@selector(setSpotifyValue:specifier:)
                                                         get:@selector(spotifyValueForSpecifier:)
                                                      detail:Nil
                                                        cell:PSSwitchCell
                                                        edit:Nil];
    [row setProperty:key forKey:@"sciSpotifyKey"];
    if (symbol.length) [row setProperty:SCIPanelBadgeImage(symbol, tint) forKey:@"iconImage"];
    return row;
}

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    //
    // **What this tweak is not, before what it is.**
    //
    // The ad blocking is carried over from a tweak whose own description offers Spotify Premium
    // for free. This one does not do that, and somebody who installs it expecting it should read
    // that here rather than discover it by trying to skip a track.
    //
    NSString *state = [self sci_readBool:@"spotify_enabled"]
        ? SCILocalized(@"spotify_gate_on")
        : SCILocalized(@"spotify_gate_off");

    [specifiers addObject:[self spotifyGroupTitled:nil
                                            footer:[NSString stringWithFormat:@"%@\n\n%@", state,
                                                       SCILocalized(@"spotify_no_premium")]]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_master")
                                                key:@"spotify_enabled"
                                             symbol:@"power"
                                               tint:SCIPanelAccent()]];

    [specifiers addObject:[self spotifyGroupTitled:SCILocalized(@"spotify_ads_section")
                                            footer:SCILocalized(@"spotify_ads_footer")]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_block_ads")
                                                key:@"spotify_block_ads"
                                             symbol:@"speaker.slash"
                                               tint:[UIColor systemGreenColor]]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_block_upsell")
                                                key:@"spotify_block_upsell"
                                             symbol:@"rectangle.slash"
                                               tint:[UIColor systemTealColor]]];

    [specifiers addObject:[self spotifyGroupTitled:SCILocalized(@"spotify_podcast_section")
                                            footer:SCILocalized(@"spotify_sponsorblock_footer")]];

    [specifiers addObject:[self spotifySwitchTitled:SCILocalized(@"spotify_sponsorblock")
                                                key:@"spotify_sponsorblock"
                                             symbol:@"forward.end"
                                               tint:[UIColor systemOrangeColor]]];

    [specifiers addObject:[self spotifyGroupTitled:nil footer:SCILocalized(@"spotify_credit")]];

    // Assigned to the ivar, not just returned: PSListController reads _specifiers directly in
    // places an override's return value never reaches, and a page that only returns its list
    // opens to a black screen -- which this project shipped once already.
    _specifiers = specifiers;
    return _specifiers;
}

@end
