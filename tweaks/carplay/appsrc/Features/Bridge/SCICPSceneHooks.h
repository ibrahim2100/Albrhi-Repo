#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs the scene-role rewrite. Safe to call unconditionally: every rewrite
/// decision inside the hooks is gated on SCICPSceneBridgeEnabledForThisApp, so an app
/// the user never enabled loads the hooks and they do nothing.
void SCICPInstallSceneHooks(void);

NS_ASSUME_NONNULL_END
