#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// SpringBoard's half of getting a bridged app onto the CarPlay dashboard.
///
/// CarPlay decides which installed apps may reach the dashboard by asking
/// `LSBundleProxy` (LaunchServices' own record of an installed app) for a handful of
/// entitlement-shaped capability keys -- `CARCapableApp`, `SBStarkCapable`. Answering
/// those for a bundle identifier the user chose is what admits it, without touching
/// the app's actual code signature.
///
/// **Known to matter on iOS 16/17 only.** iOS 18 moved the real admission gate to
/// `+[CRCarPlayAppDeclaration requiredEntitlementKeys]`, which reads code-signed
/// entitlements at app-registration time -- outside any process a tweak can inject
/// into, and unreachable without an on-disk re-signing step this project has not
/// built yet (see CHANGELOG.md). This spoof installs unconditionally regardless: it
/// is a narrow, guarded swizzle on a class that exists on every iOS version, and
/// where it cannot change anything it simply changes nothing, which is the same
/// "installed but inert" shape the panel's own on/off switch already uses rather
/// than being version-gated code that might itself be wrong about which version it
/// is running on.
///
void SCICPInstallAdmissionSpoof(void);

NS_ASSUME_NONNULL_END
