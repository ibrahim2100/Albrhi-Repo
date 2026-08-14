#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The piece SCICPAdmissionSpoof.h's own entitlement getters cannot reach: before
/// CarPlay ever launches an app, it reads that app's *declared* scene configuration
/// through `LSBundleProxy -objectForInfoDictionaryKey:ofClass:` -- LaunchServices'
/// installed-app record, not the app's live process -- to decide whether trying a
/// CarPlay scene for it is worth attempting at all. An ordinary app's real
/// `Info.plist` has no `UIWindowSceneSessionRoleCarPlay` entry, so without this,
/// CarPlay can answer every entitlement question YES and still never ask the app for
/// a scene in the first place: admitted to the library, never actually opened.
///
/// This adds exactly that one scene-configuration entry to what LSBundleProxy hands
/// back for `UIApplicationSceneManifest`, preserving every configuration the app
/// already declares -- nothing here removes the app's own window-scene role, only
/// adds a CarPlay one pointing at the same configuration name UIKit resolves anyway
/// once SCICPSceneHooks.x's role rewrite runs inside the app's own process. Also
/// declares `SBStarkLaunchModes` when absent, the other flag CarPlay's dashboard
/// build was observed asking LSBundleProxy for.
///
void SCICPInstallSceneManifestSpoof(void);

NS_ASSUME_NONNULL_END
