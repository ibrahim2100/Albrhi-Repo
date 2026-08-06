#import "SCIPanelGate.h"

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

BOOL SCIPanelAllowsThisApp(void) {
    static BOOL allowed = YES;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSString *key = SCIPanelKeyForThisApp();
        if (!key) return;   // no bundle id to ask about; leave it on

        // CFPreferences rather than a file read: this runs inside a sandboxed app, which
        // cannot open /var/mobile/Library/Preferences itself. cfprefsd can, and the sandbox
        // permits talking to it.
        CFPropertyListRef value = CFPreferencesCopyAppValue(
            (__bridge CFStringRef)key, (__bridge CFStringRef)kSCIPanelDomain);

        if (!value) return;   // never written; the default stands

        if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
            allowed = CFBooleanGetValue((CFBooleanRef)value);
        }
        CFRelease(value);
    });

    return allowed;
}
