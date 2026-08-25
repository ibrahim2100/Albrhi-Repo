//
//  YTMShared.h
//  Albrhi for YouTube Music
//
//  What every carried-over hook file needs: the switch reader, and the app interfaces.
//
//  **One reader, not one per file.** Upstream repeats the same six-line `YTMU()` in every source,
//  which is how a dictionary name gets spelled two ways -- the exact failure this project already
//  records for the panel's own preference domain. It is written once here and imported.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "Headers/YTMUpstream.h"

/// Upstream's own switch dictionary, composed by Tweak.x from Albrhi's per-app switch.
static inline BOOL YTMU(NSString *key) {
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [settings[key] boolValue];
}

static inline NSInteger YTMUInt(NSString *key) {
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [settings[key] integerValue];
}
