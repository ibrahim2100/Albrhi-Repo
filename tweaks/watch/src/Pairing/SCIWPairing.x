#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>
#import "SCIWPairing.h"
#import "../Prefs.h"
#import "../Diagnostics/SCIWDiagnostics.h"

///
/// The pairing core, from `watched` by 34306 (github.com/34306/watched), MIT.
///
/// **This is carried-over code, not a reimplementation, and the difference is the licence.**
/// MIT permits exactly this, which is why the pairing answers below read as they do upstream
/// rather than being rewritten in this project's idiom -- the same decision Albrhi NextUp made
/// under GPLv3, and the opposite of what the unlicensed TikTok references got. `LICENSE-watched`
/// ships in the package because MIT asks for that and asks for nothing else.
///
/// What this port adds, and all of it is in the guards rather than the answers:
///
///  - **Every group is behind a switch**, so a device that pairs but misbehaves can have one
///    third of the tweak turned off rather than the whole package removed. Upstream installs all
///    three unconditionally, which is right for a tweak with no settings and wrong once there are.
///  - **Every answer is counted** (`SCIWRecordAnswer`). A pairing failure looks identical to a
///    tweak that never loaded, and the only screen that could tell them apart is the pairing
///    screen itself, which shows neither.
///  - The preference writes are gated on the same switch as the hooks they support, so turning
///    pairing off stops rewriting NanoRegistry's limits on the next launch rather than leaving
///    the last values behind for good.
///
/// The version arithmetic is upstream's and worth reading rather than skimming: watchOS trailed
/// iOS by seven for years (watchOS 11 against iOS 18), and from **26** Apple aligned the numbers.
/// So a major below 26 gets the offset added before it is compared, and one at or above it does
/// not. Two lines that survive the renumbering.
///

static const NSInteger kSCIWAlignedMajorVersion = 26;
static const NSInteger kSCIWWatchOSToIOSOffset = 7;

static const long long kSCIWMaxPairingVersion = 999;
static const long long kSCIWMinPairingVersion = 1;

static NSString *const kSCIWNanoRegistryDomain = @"com.apple.NanoRegistry";
static NSString *const kSCIWPairedSyncDomain = @"com.apple.pairedsync";

#pragma mark - Preferences

static BOOL SCIWWritePreference(NSString *domain, NSString *key, id value) {
    CFStringRef cfDomain = (__bridge CFStringRef)domain;
    CFStringRef cfKey = (__bridge CFStringRef)key;

    // Read before writing, and report whether anything changed: a write that stores what is
    // already stored still costs a synchronise and a cache flush, and this runs at every launch
    // of SpringBoard.
    CFPropertyListRef current = CFPreferencesCopyValue(cfKey, cfDomain, CFSTR("mobile"),
                                                       kCFPreferencesAnyHost);
    BOOL unchanged = current && CFEqual(current, (__bridge CFTypeRef)value);
    if (current) CFRelease(current);
    if (unchanged) return NO;

    CFPreferencesSetValue(cfKey, (__bridge CFPropertyListRef)value, cfDomain, CFSTR("mobile"),
                          kCFPreferencesAnyHost);
    return YES;
}

static void SCIWFlushPreferenceCache(NSString *domain) {
    static void (*flush)(CFStringRef, CFStringRef);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        flush = (void (*)(CFStringRef, CFStringRef))
            dlsym(RTLD_DEFAULT, "_CFPreferencesFlushCachesForIdentifier");
    });
    if (flush) flush((__bridge CFStringRef)domain, CFSTR("mobile"));
}

///
/// The limits, written where the processes that never ask a hooked class can still read them.
///
/// **`geteuid() != 501` is upstream's, and it stays.** The filter names SpringBoard, but a filter
/// is a request to MobileSubstrate rather than a guarantee about who ends up running this code,
/// and these values belong to the `mobile` user's own preference domain. Writing them from
/// anything else would put them where nothing reads them at best.
///
static void SCIWApplyPairingPreferences(void) {
    if (geteuid() != 501) return;

    BOOL changed = NO;
    changed |= SCIWWritePreference(kSCIWNanoRegistryDomain, @"minPairingCompatibilityVersion",
                                   @(kSCIWMinPairingVersion));
    changed |= SCIWWritePreference(kSCIWNanoRegistryDomain, @"maxPairingCompatibilityVersion",
                                   @(kSCIWMaxPairingVersion));
    changed |= SCIWWritePreference(kSCIWNanoRegistryDomain,
                                   @"minPairingCompatibilityVersionWithChipID",
                                   @(kSCIWMinPairingVersion));
    changed |= SCIWWritePreference(kSCIWNanoRegistryDomain, @"minQuickSwitchCompatibilityVersion",
                                   @(kSCIWMinPairingVersion));
    changed |= SCIWWritePreference(kSCIWNanoRegistryDomain,
                                   @"IOS_PAIRING_EOL_MIN_PAIRING_COMPATIBILITY_VERSION_CHIPIDS",
                                   @"");

    if (changed) {
        CFPreferencesSynchronize((__bridge CFStringRef)kSCIWNanoRegistryDomain, CFSTR("mobile"),
                                 kCFPreferencesAnyHost);
        SCIWFlushPreferenceCache(kSCIWNanoRegistryDomain);
        SCIWRecordAnswer(@"NanoRegistry limits written");
    }

    if (SCIWWritePreference(kSCIWPairedSyncDomain, @"activityTimeout", @30)) {
        CFPreferencesSynchronize((__bridge CFStringRef)kSCIWPairedSyncDomain, CFSTR("mobile"),
                                 kCFPreferencesAnyHost);
        SCIWFlushPreferenceCache(kSCIWPairedSyncDomain);
        SCIWRecordAnswer(@"pairedsync timeout written");
    }
}

#pragma mark - Runtime

@interface NRPairingCompatibilityVersionInfo : NSObject
@end

@interface NRDevice : NSObject
- (id)valueForProperty:(id)property;
@end

@interface NRMutableDevice : NRDevice
@end

@interface ACXRemoteApplication : NSObject
@end

/// A NanoRegistry property key, read from the framework's own exported symbol rather than
/// spelled out here. The string constant is what `-valueForProperty:` expects, and its *value*
/// is not guaranteed to equal its symbol name.
static NSString *SCIWNanoRegistryPropertyKey(const char *symbol) {
    void *address = dlsym(RTLD_DEFAULT, symbol);
    return address ? *(NSString *__unsafe_unretained *)address : nil;
}

static BOOL SCIWDeviceRunsNewerOSThanHost(NRDevice *device) {
    static NSString *marketingKey, *systemKey;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        marketingKey = SCIWNanoRegistryPropertyKey("NRDevicePropertyMarketingVersion");
        systemKey = SCIWNanoRegistryPropertyKey("NRDevicePropertySystemVersion");
    });

    id version = marketingKey ? [device valueForProperty:marketingKey] : nil;
    if (![version isKindOfClass:NSString.class] && systemKey) {
        version = [device valueForProperty:systemKey];
    }
    if (![version isKindOfClass:NSString.class]) return NO;

    NSInteger major = [(NSString *)version integerValue];
    if (major <= 0) return NO;
    if (major < kSCIWAlignedMajorVersion) major += kSCIWWatchOSToIOSOffset;

    NSInteger host = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    SCIWRecordWatchVersion(major, host);
    return major > host;
}


%group Capabilities

%hook NRDevice
- (BOOL)supportsCapability:(id)capability {
    if (!SCIWPrefEnabledForKey(SCIWPrefCapabilities)) {
        return %orig;
    }
    SCIWRecordAnswer(@"NRDevice capability");
    return %orig ?: SCIWDeviceRunsNewerOSThanHost(self);
}
%end

%hook NRMutableDevice
- (BOOL)supportsCapability:(id)capability {
    if (!SCIWPrefEnabledForKey(SCIWPrefCapabilities)) {
        return %orig;
    }
    SCIWRecordAnswer(@"NRMutableDevice capability");
    return %orig ?: SCIWDeviceRunsNewerOSThanHost(self);
}
%end

%end


%group Apps

%hook ACXRemoteApplication
- (BOOL)isRuntimeCompatibleWithOSVersion:(id)version {
    if (!SCIWPrefEnabledForKey(SCIWPrefApps)) {
        return %orig;
    }
    SCIWRecordAnswer(@"companion app runtime");
    return YES;
}
%end

%end


%group PairingGate

%hook NRPairingCompatibilityVersionInfo

- (long long)maxPairingCompatibilityVersion {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    SCIWRecordAnswer(@"max pairing version");
    return kSCIWMaxPairingVersion;
}

- (long long)minPairingCompatibilityVersion {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    SCIWRecordAnswer(@"min pairing version");
    return kSCIWMinPairingVersion;
}

- (long long)minPairingCompatibilityVersionWithChipID {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMinPairingVersion;
}

- (long long)minQuickSwitchCompatibilityVersion {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMinPairingVersion;
}

- (long long)minPairingCompatibilityVersionForChipID:(id)chipID {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMinPairingVersion;
}

- (long long)minPairingCompatibilityVersionForChipID:(id)chipID
                                                name:(id)name
                                      defaultVersion:(long long)version {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMinPairingVersion;
}

- (long long)minQuickSwitchPairingCompatibilityVersionForChipID:(id)chipID {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMinPairingVersion;
}

- (long long)minPairingCompatibilityVersionForWatchProductType:(id)productType {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMinPairingVersion;
}

- (long long)maxPairingCompatibilityVersionForPhoneProductType:(id)productType {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    return kSCIWMaxPairingVersion;
}

- (unsigned long long)pairingCompatibilitySupportStateForAdvertisingWatchVersion:(long long)version {
    if (!SCIWPrefEnabledForKey(SCIWPrefPairing)) {
        return %orig;
    }
    SCIWRecordAnswer(@"advertised watch version");
    return 1;
}

%end

%end


void SCIWInstallPairing(void) {
    // Recorded whether present or not, and before anything is installed: "the hook never ran"
    // and "the class is not in this build" are the two explanations for the same silence, and
    // only this distinguishes them.
    BOOL gate = NSClassFromString(@"NRPairingCompatibilityVersionInfo") != nil;
    BOOL device = NSClassFromString(@"NRDevice") != nil;
    BOOL apps = NSClassFromString(@"ACXRemoteApplication") != nil;

    SCIWRecordClass(@"NRPairingCompatibilityVersionInfo", gate);
    SCIWRecordClass(@"NRDevice", device);
    SCIWRecordClass(@"ACXRemoteApplication", apps);

    if (gate) %init(PairingGate);
    if (device) %init(Capabilities);
    if (apps) %init(Apps);

    // The writes are behind the same switch as the gate they support, and they run after the
    // hooks so a launch with the master off leaves NanoRegistry exactly as iOS left it.
    // The hooks go into every process that asks the question; the *writes* stay in SpringBoard.
    // They are global values with one correct writer, and geteuid() would refuse them anywhere
    // else in any case -- but naming the process says why rather than relying on a uid check to
    // mean something it does not say.
    BOOL isSpringBoard = [[[NSBundle mainBundle] bundleIdentifier]
                             isEqualToString:@"com.apple.springboard"];
    if (isSpringBoard && SCIWPrefEnabledForKey(SCIWPrefPairing)) SCIWApplyPairingPreferences();
}
