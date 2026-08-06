#import "SCIPanelGate.h"
#import <dlfcn.h>

/// The panel's own preference domain. Both sides name it here rather than each spelling it
/// out: a typo on one side is a switch that appears to work and changes nothing.
static NSString *const kSCIPanelDomain = @"com.albrhi.panel";

/// One key per app, so the panel can write a decision about an app it has never seen a
/// tweak for, and so two tweaks in the same app are governed by the same switch — which is
/// what "turn this app off" means to the person reading it.
static NSString *SCIPanelKeyForThisApp(void) {
    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    return bundle.length ? [@"app_enabled_" stringByAppendingString:bundle] : nil;
}

/// Where this dylib is, and therefore where the jailbreak is.
///
/// Rootful is "/", rootless "/var/jb", and roothide a directory with a different random
/// name on every device — so a list of candidates is wrong on roothide by construction.
/// dladdr answers with the path this very code was loaded from, and the prefix is three
/// components above <prefix>/Library/MobileSubstrate/DynamicLibraries/X.dylib.
static NSString *SCIJailbreakPrefix(void) {
    Dl_info info = {0};
    if (dladdr((const void *)&SCIPanelKeyForThisApp, &info) == 0 || !info.dli_fname) return @"/";

    NSString *me = [NSString stringWithUTF8String:info.dli_fname];
    NSString *up = [[[me stringByDeletingLastPathComponent]     // DynamicLibraries
                          stringByDeletingLastPathComponent]     // MobileSubstrate
                          stringByDeletingLastPathComponent];    // Library
    return up.stringByDeletingLastPathComponent.length ? up.stringByDeletingLastPathComponent : @"/";
}

/// Where the answer came from, so a diagnostics page can say it.
static NSString *sciGateSource = nil;

///
/// Reads the switch the panel wrote.
///
/// **CFPreferences alone did not work, and that is what this file is really about.** The
/// panel runs inside the Settings app and writes the domain there; this code runs inside
/// Instagram or YouTube, which are sandboxed, and a sandboxed process asking cfprefsd for
/// another application's domain is answered with nothing rather than with an error. So the
/// tweak read an absence, and an absence means "on" — which is exactly what was reported:
/// the switch moved, and nothing changed in the app.
///
/// The file is therefore read directly. On a jailbroken device the sandbox permits it, and
/// unlike the daemon it cannot quietly decide the question belongs to a different container.
/// CFPreferences is still tried first because where it does work it is the cheaper answer
/// and it sees a value that has been written but not yet flushed to disk.
///
static BOOL SCIPanelReadSwitch(NSString *key, BOOL fallback) {
    // 1. The daemon. Correct where the sandbox allows it, and free when it does not.
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kSCIPanelDomain);

    if (value) {
        BOOL answer = fallback;
        if (CFGetTypeID(value) == CFBooleanGetTypeID()) answer = CFBooleanGetValue((CFBooleanRef)value);
        CFRelease(value);
        sciGateSource = @"preferences daemon";
        return answer;
    }

    // 2. The file itself. The panel writes through CFPreferences from the Settings app, so
    //    the plist lands in the real /var/mobile tree; the jailbreak-prefixed path is tried
    //    as well because a rootless or roothide bootstrap can put it under its own root.
    NSString *leaf = [NSString stringWithFormat:@"var/mobile/Library/Preferences/%@.plist",
                      kSCIPanelDomain];

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    [candidates addObject:[@"/" stringByAppendingPathComponent:leaf]];

    NSString *prefix = SCIJailbreakPrefix();
    if (prefix.length > 1) {
        [candidates addObject:[prefix stringByAppendingPathComponent:leaf]];
    }

    for (NSString *path in candidates) {
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
        id stored = plist[key];
        if ([stored isKindOfClass:[NSNumber class]]) {
            sciGateSource = path;
            return [stored boolValue];
        }
    }

    // Nothing written anywhere. Said as its own answer rather than folded into "on":
    // "never switched off" and "switched off and unreadable" are the two explanations
    // this whole file exists to separate.
    sciGateSource = [NSString stringWithFormat:@"nothing written (looked in %lu places)",
                     (unsigned long)candidates.count];
    return fallback;
}

BOOL SCIPanelAllowsThisApp(void) {
    static BOOL allowed = YES;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSString *key = SCIPanelKeyForThisApp();
        if (!key) return;   // no bundle id to ask about; leave it on

        // Absent reads as on. A device that has never opened the panel has every tweak it
        // installed deliberately still working, which is the only safe reading of nothing.
        allowed = SCIPanelReadSwitch(key, YES);
    });

    return allowed;
}

NSString *SCIPanelGateReport(void) {
    // Asked through the gate so the answer and the account of it can never disagree.
    BOOL allowed = SCIPanelAllowsThisApp();

    return [NSString stringWithFormat:@"%@ — %@",
            allowed ? @"on" : @"off",
            sciGateSource ?: @"not consulted"];
}
