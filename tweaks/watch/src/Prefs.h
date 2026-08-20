#import <Foundation/Foundation.h>

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

/// Hold watchOS updates: the Watch app stops going looking for them.
///
/// **Off by default, and it is the one switch here that stops something the phone would otherwise
/// do for you.** Everything else in this tweak *answers* a question iOS asks; this one refuses to
/// ask it. Somebody who installs a pairing tweak has not asked for their watch to stop being
/// offered updates, so it waits to be turned on.
#define SCIWPrefHoldUpdates     CFSTR("watch_hold_updates")

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

///
/// This tweak's master, then the feature's own — and **not** Albrhi Panel's per-app switch.
///
/// `SCIPanelAllowsThisApp()` asks whether `app_enabled_com.apple.springboard` is set, and **there
/// is no switch anywhere that sets it**: the panel draws that switch on an app's own row, and this
/// tweak is deliberately collapsed into one grouped row instead (`SCIPanelGroupIdentifier`), so its
/// two processes never appear as apps at all. Asking a question nobody can answer means the gate
/// refuses forever: nothing installs, the probe never runs, and the report stays empty — which is
/// exactly how this shipped and exactly what the first device report said.
///
/// **The master switch on the tweak's own page is the gate**, which is also what Albrhi NextUp
/// does for the same reason. The panel's per-app switch is for tweaks that patch one app and get
/// one row; a tweak that spans SpringBoard and the Watch app is not that shape.
///
static inline BOOL SCIWPrefEnabledForKey(CFStringRef key) {
    if (!SCIWReadPreference(SCIWPrefEnabled, NO)) return NO;
    return SCIWReadPreference(key, YES);
}
