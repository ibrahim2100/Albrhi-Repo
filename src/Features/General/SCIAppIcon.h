#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Alternate app icons.
///
/// Instagram ships a set of alternate icons for its paid subscribers and declares
/// them in its own Info.plist. Because they are declared there, -setAlternateIconName:
/// accepts them with no subscription involved — the paywall is on the storefront,
/// not on the icons themselves. This reads whatever the installed build declares
/// rather than hard-coding a list, so it follows Instagram from one version to the
/// next instead of pinning to one.
///
@interface SCIAppIcon : NSObject

/// The alternate icon names the installed Instagram declares, in declaration order.
/// Empty when the build declares none or the device does not allow changing icons.
+ (NSArray<NSString *> *)availableIconNames;

/// The icon in use now, or nil for Instagram's default.
+ (nullable NSString *)currentIconName;

/// Applies an icon by name, or restores the default with nil. Safe to call from the
/// main thread; reports success or failure through a toast.
+ (void)applyIconNamed:(nullable NSString *)name;

/// A menu of "Default" plus every declared icon, the current one checked, each entry
/// applying itself when chosen. nil when the build offers no alternates.
+ (nullable UIMenu *)iconMenu;

@end

NS_ASSUME_NONNULL_END
