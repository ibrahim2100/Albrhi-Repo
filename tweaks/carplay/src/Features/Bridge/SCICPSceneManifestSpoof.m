#import "SCICPSceneManifestSpoof.h"
#import "SCICPLSProxy.h"
#import "SCILog.h"
#import "SCICPBridgeList.h"
#import "../../Diagnostics/SCICPDiagnostics.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const kSCICPCarPlayRoleKey = @"UIWindowSceneSessionRoleCarPlay";
static NSString *const kSCICPSceneConfigurationsKey = @"UISceneConfigurations";
static NSString *const kSCICPMultipleScenesKey = @"UIApplicationSupportsMultipleScenes";
static NSString *const kSCICPSceneManifestKey = @"UIApplicationSceneManifest";
static NSString *const kSCICPStarkLaunchModesKey = @"SBStarkLaunchModes";

/// Adds a CarPlay window-scene configuration to whatever the app already declares,
/// touching nothing else: the app's own window-scene role stays exactly as it was,
/// because removing it would break the app everywhere it is not bridged.
///
/// No `UISceneDelegateClassName` in the entry added here -- this project cannot know
/// the app's own delegate class, and does not need to: SCICPSceneHooks.x rewrites
/// whatever role CarPlay asks for onto the app's *own* default window-scene
/// configuration once the app's process is actually running. This only has to make
/// CarPlay believe, before that process ever starts, that trying a CarPlay scene for
/// this app is worth attempting at all.
static NSDictionary *SCICPManifestWithCarPlayRole(NSDictionary *original) {
    NSDictionary *existing = [original[kSCICPSceneConfigurationsKey] isKindOfClass:NSDictionary.class]
        ? original[kSCICPSceneConfigurationsKey] : nil;

    if (existing[kSCICPCarPlayRoleKey]) return original;   // already declares one

    NSMutableDictionary *configurations = existing ? [existing mutableCopy] : [NSMutableDictionary new];
    configurations[kSCICPCarPlayRoleKey] = @[ @{ @"UISceneConfigurationName": @"AlbrhiCPCarPlay" } ];

    NSMutableDictionary *result = original ? [original mutableCopy] : [NSMutableDictionary new];
    result[kSCICPSceneConfigurationsKey] = configurations;
    result[kSCICPMultipleScenesKey] = @YES;
    return result;
}

static id (*sciOrigObjectForInfoDictionaryKey)(id, SEL, NSString *, Class);

static id sciObjectForInfoDictionaryKey(id self, SEL _cmd, NSString *key, Class expected) {
    id value = sciOrigObjectForInfoDictionaryKey(self, _cmd, key, expected);

    @try {
        NSString *bundleID = SCICPLSProxyBundleIdentifier(self);
        if (!bundleID || !SCICPBundleIsBridged(bundleID)) return value;

        if ([key isEqualToString:kSCICPStarkLaunchModesKey]) {
            if (value) return value;   // already declares it
            if (expected && expected != NSArray.class) return value;
            SCILogV(@"manifest: declared %@ for %@", kSCICPStarkLaunchModesKey, bundleID);
            return @[ @"Default" ];
        }

        if (![key isEqualToString:kSCICPSceneManifestKey]) return value;
        if (expected && expected != NSDictionary.class) return value;

        NSDictionary *original = [value isKindOfClass:NSDictionary.class] ? value : nil;
        NSDictionary *patched = SCICPManifestWithCarPlayRole(original);
        if (patched == original) return value;   // already had a CarPlay role

        SCILogV(@"manifest: added a CarPlay scene configuration for %@", bundleID);
        [SCICPDiagnostics record:
            [NSString stringWithFormat:@"manifest: added a CarPlay scene configuration for %@",
                bundleID]];
        return patched;
    } @catch (__unused NSException *exception) {
        SCILogV(@"manifest: spoof suppressed an exception for key %@", key);
        return value;
    }
}

void SCICPInstallSceneManifestSpoof(void) {
    Class proxy = NSClassFromString(@"LSBundleProxy");
    if (!proxy) {
        SCILogV(@"manifest: LSBundleProxy absent — nothing to hook");
        return;
    }

    BOOL info = SCICPSwizzleInstanceMethod(
        proxy, sel_getUid("objectForInfoDictionaryKey:ofClass:"),
        (IMP)sciObjectForInfoDictionaryKey, (IMP *)&sciOrigObjectForInfoDictionaryKey);

    SCILogV(@"manifest: scene-manifest spoof installed (info=%d)", info);

    if (!info) {
        SCILogV(@"manifest: WARNING objectForInfoDictionaryKey:ofClass: not found on "
                "this build — CarPlay will not see a CarPlay scene declared for any "
                "bridged app");
    }
}
