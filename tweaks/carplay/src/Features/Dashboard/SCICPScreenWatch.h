#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Whether a CarPlay screen is connected right now, and nothing more.
///
/// **This is the entire first step toward a dashboard, on purpose.** Everything past
/// this -- putting an app's live view on that screen -- means walking through private
/// SpringBoard classes (`SBSceneManagerCoordinator`, `SBApplicationSceneHandleRequest`,
/// `SBAppViewController`) that this project has only read about in a licensed
/// reference, never confirmed against a real device. This project's own ground rule is
/// not to guess at what a class dump says exists versus what it actually does at
/// runtime -- Instagram paid for that lesson twice. So this reads only what is public,
/// documented, and asks nothing of a version-specific private API: `UIScreen.screens`
/// and the two connect/disconnect notifications, which have been stable public UIKit
/// API since external displays existed at all.
///
@interface SCICPScreenWatch : NSObject

/// Starts observing. Safe to call more than once; the second call does nothing.
+ (void)start;

/// Whether a screen beyond the device's own is in `UIScreen.screens` right now.
///
/// **Named for what it actually detects.** A phone has no everyday reason to gain a
/// second `UIScreen` other than CarPlay -- an AirPlay TV or an HDMI adapter would
/// technically also trigger this -- so it is a strong signal rather than a certain one,
/// and it is reported as exactly that: an external screen, with its own description
/// logged for a person to confirm by eye, not asserted as CarPlay from a name this
/// project has not verified UIKit actually exposes.
+ (BOOL)isExternalScreenConnected;

@end

NS_ASSUME_NONNULL_END
