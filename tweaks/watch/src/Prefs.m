//
//  Prefs.m
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "Prefs.h"
#import <dlfcn.h>

static NSString *sciwPreferenceSource = nil;

///
/// Where this dylib is, and therefore where the jailbreak is.
///
/// Rootful is `/`, rootless `/var/jb`, and roothide a directory with a different random name on
/// every device — so a list of candidates is wrong on roothide by construction. `dladdr` answers
/// with the path this very code was loaded from, and the prefix is three components above
/// `<prefix>/Library/MobileSubstrate/DynamicLibraries/X.dylib`.
///
static NSString *SCIWJailbreakPrefix(void) {
    Dl_info info = {0};
    if (dladdr((const void *)&SCIWReadPreference, &info) == 0 || !info.dli_fname) return @"/";

    NSString *me = [NSString stringWithUTF8String:info.dli_fname];
    NSString *up = [[[me stringByDeletingLastPathComponent]      // DynamicLibraries
                         stringByDeletingLastPathComponent]      // MobileSubstrate
                         stringByDeletingLastPathComponent];     // Library
    NSString *root = up.stringByDeletingLastPathComponent;
    return root.length ? root : @"/";
}

static id SCIWCopyRawValue(CFStringRef key) {
    // 1. The daemon. Correct where the sandbox allows it, and free where it does not.
    CFPreferencesAppSynchronize(SCIWDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, SCIWDomain);
    if (value) {
        sciwPreferenceSource = @"preferences daemon";
        return (__bridge_transfer id)value;
    }

    // 2. The file. The panel writes through CFPreferences from Settings, so the plist lands in the
    //    real /var/mobile tree; the jailbreak-prefixed path is tried too, because a rootless or
    //    roothide bootstrap can put it under its own root.
    NSString *leaf = [NSString stringWithFormat:@"var/mobile/Library/Preferences/%@.plist",
                      (__bridge NSString *)SCIWDomain];

    NSMutableArray<NSString *> *candidates =
        [NSMutableArray arrayWithObject:[@"/" stringByAppendingPathComponent:leaf]];

    NSString *prefix = SCIWJailbreakPrefix();
    if (prefix.length > 1) [candidates addObject:[prefix stringByAppendingPathComponent:leaf]];

    for (NSString *path in candidates) {
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
        id stored = plist[(__bridge NSString *)key];
        if (stored) {
            sciwPreferenceSource = path;
            return stored;
        }
    }

    // Nothing written anywhere. Its own answer rather than folded into the fallback: "never
    // switched on" and "switched on and unreadable" are the two this lookup exists to separate.
    sciwPreferenceSource = [NSString stringWithFormat:@"nothing written (looked in %lu place(s))",
                            (unsigned long)candidates.count];
    return nil;
}

BOOL SCIWReadPreference(CFStringRef key, BOOL fallback) {
    id value = SCIWCopyRawValue(key);
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

NSInteger SCIWReadInteger(CFStringRef key, NSInteger fallback) {
    id value = SCIWCopyRawValue(key);
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : fallback;
}

NSString *SCIWPreferenceSource(void) {
    return sciwPreferenceSource ?: @"nothing has been read yet";
}
