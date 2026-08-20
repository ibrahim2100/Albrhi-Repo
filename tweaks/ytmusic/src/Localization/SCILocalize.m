//
//  SCILocalize.m
//  Albrhi for YouTube Music
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCILocalize.h"

NSString *SCIVersionString = @"v0.1.1";  // AlbrhiYTM

/// Short, because everything a person reads about this tweak is drawn by Albrhi Panel: it patches
/// one app, so it takes one row on the app list rather than a page of its own.
static NSDictionary *_enTable = nil;
static NSDictionary *_arTable = nil;

static void SCIBuildTables(void) {
    _enTable = @{
        @"title": @"Albrhi for YouTube Music",
        @"no_premium": @"Ads only. This does not unlock Premium.",
    };

    _arTable = @{
        @"title": @"البرهي ليوتيوب ميوزك",
        @"no_premium": @"الإعلانات فقط. لا يفتح Premium.",
    };
}

NSString *SCILocalized(NSString *key) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SCIBuildTables(); });

    BOOL arabic = [[NSLocale preferredLanguages].firstObject hasPrefix:@"ar"];
    NSString *value = arabic ? _arTable[key] : _enTable[key];
    return value ?: (_enTable[key] ?: key);
}
