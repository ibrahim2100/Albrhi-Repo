#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The app's own half of getting its real interface onto the CarPlay dashboard.
///
/// CarPlay drives an app it has admitted through a `CPTemplateApplicationScene*`
/// role -- a cut-down template interface, not the app's actual UI. Rewriting that
/// role to an ordinary `UIWindowSceneSessionRoleApplication` before UIKit resolves it
/// makes UIKit look up the app's own window-scene configuration instead and hand the
/// scene to the app's real scene delegate: the app renders its normal phone interface
/// on the car screen, with no idea the display is a car. See SCICPSceneHooks.x for
/// where that rewrite actually happens -- both public UIKit selectors
/// (`-[UISceneConfiguration initWithName:sessionRole:]`, `-[UISceneSession role]`),
/// intercepted for an unintended purpose rather than guessed-at private API.
///
/// **Only for a bundle the user actually enabled.** This dylib is filtered onto every
/// app that links UIKit -- there is no other reliable way to reach "whichever app the
/// user picks" -- so every rewrite decision is gated on
/// SCICPBundleIsBridged(NSBundle.mainBundle.bundleIdentifier) first.
///
/// **What this deliberately does not do yet.** An app with no scene manifest at all
/// (`UIApplicationSceneManifest` absent or empty) has nothing for the role rewrite to
/// resolve against and simply never gets a car scene -- no crash, the feature just
/// does not reach that app. Moving its one window onto the car display and back is a
/// separate, larger piece (transplanting a view controller between windows) left for
/// after this is confirmed working for an ordinary multi-scene app.
///
/// Whether *this* process's own bundle is one the user chose to bridge. Read once and
/// cached: the answer cannot change during a running process, same reasoning as
/// SCIPanelAllowsThisApp.
BOOL SCICPSceneBridgeEnabledForThisApp(void);

/// A CarPlay template scene-session role -- the one this project rewrites away from.
BOOL SCICPIsTemplateSceneRole(NSString *_Nullable role);

NS_ASSUME_NONNULL_END
