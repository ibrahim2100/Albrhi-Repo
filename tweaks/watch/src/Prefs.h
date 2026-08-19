#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"

///
/// Every preference this tweak has, named once — and read from a domain both sides agree on.
///
/// **`NSUserDefaults` would not have worked here, and the reason is the whole shape of this
/// project's panel.** The switches are written by Albrhi Panel, which runs inside Settings, and
/// read by this tweak, which runs inside SpringBoard. `standardUserDefaults` means "the calling
/// process's own domain", so the panel would write Settings' preferences and SpringBoard would
/// read its own: two files, one name, and a switch that appears to work and changes nothing.
/// CLAUDE.md records the release where exactly that shipped.
///
/// So the domain is named on both sides, and both use CFPreferences against it. SpringBoard runs
/// as `mobile` and can read the `mobile` user's own domain, which is where Settings writes.
///
/// **No libSandy here, and the reason is which process this is.** `vendor/libSandy` is in this
/// repository because Albrhi NextUp needs it: five of its seven targets are App Store apps whose
/// sandbox denies both the shared preferences directory and registering a mach service. SpringBoard
/// is neither sandboxed that way nor asking for a service, so a dependency that grants what is
/// already granted would only add a package somebody has to install.
///
/// **It becomes necessary the moment this tweak grows.** Photo, music and Maps support live inside
/// Photos, Music and Maps -- sandboxed apps, where reading `com.albrhi.watch` is exactly the denial
/// libSandy exists for, and where `SCIPanelGate`'s own direct-plist fallback already had to be
/// written for the same reason. The vendored copy is here when that day comes.
///
#define SCIWDomain              CFSTR("com.albrhi.watch")

/// The master. **Off until it is turned on**: this tweak answers the questions iOS asks before it
/// agrees to pair with a watch, and nothing about that should begin because a package landed.
#define SCIWPrefEnabled         CFSTR("watch_enabled")

/// The pairing gate — the ten compatibility-version answers, and the NanoRegistry limits written
/// for the processes that read the preference rather than ask the class.
#define SCIWPrefPairing         CFSTR("watch_pairing")

/// `-supportsCapability:` answered for a watch running a newer OS than the phone. Separate from
/// the gate because it is a different claim: the gate says this pairing is allowed, this says the
/// watch can do the thing being asked about. A watch that pairs but refuses one feature is
/// diagnosed by turning exactly one of these off.
#define SCIWPrefCapabilities    CFSTR("watch_capabilities")

/// Companion app installation: `ACXRemoteApplication -isRuntimeCompatibleWithOSVersion:`.
#define SCIWPrefApps            CFSTR("watch_apps")

///
/// One switch, read fresh.
///
/// `fresh` matters in SpringBoard: cfprefsd caches another domain's values per process, and the
/// switch that was just moved in Settings is precisely the one being asked about. The hooks read
/// this on every call rather than at launch, so turning a feature off takes effect without a
/// respring even though *installing* the hooks needed one.
///
static inline BOOL SCIWReadPreference(CFStringRef key, BOOL fallback) {
    CFPreferencesAppSynchronize(SCIWDomain);

    CFPropertyListRef value = CFPreferencesCopyAppValue(key, SCIWDomain);
    if (!value) return fallback;

    BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : fallback;
    CFRelease(value);
    return result;
}

/// Albrhi Panel's per-app switch, then this tweak's master, then the feature's own.
///
/// Three gates that mean three things: "Albrhi may act in this process", "this tweak is on", and
/// "this part of it is on". The features default *on* so the one master switch is enough to get a
/// working tweak; the master defaults off.
static inline BOOL SCIWPrefEnabledForKey(CFStringRef key) {
    if (!SCIPanelAllowsThisApp()) return NO;
    if (!SCIWReadPreference(SCIWPrefEnabled, NO)) return NO;
    return SCIWReadPreference(key, YES);
}
