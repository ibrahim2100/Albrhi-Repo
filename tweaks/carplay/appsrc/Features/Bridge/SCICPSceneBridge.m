#import "SCICPSceneBridge.h"
#import "SCILog.h"
#import "SCICPBridgeList.h"

BOOL SCICPSceneBridgeEnabledForThisApp(void) {
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        enabled = SCICPBundleIsBridged(bundleID);
        SCILogV(@"scene bridge: %@ for %@", enabled ? @"enabled" : @"not enabled",
                bundleID ?: @"(no bundle id)");
    });
    return enabled;
}

/// Every real CarPlay template role shares this prefix -- one for the main app scene,
/// separate ones for a dashboard widget or an instrument-cluster scene. Only the
/// application role is ever rewritten; the widget and cluster roles are left alone on
/// purpose, the same restraint carsurf's own README documents for the same reason:
/// putting a full app UI where the car expects a small widget is not an improvement.
static NSString *const kSCICPTemplateApplicationRole =
    @"CPTemplateApplicationSceneSessionRoleApplication";

BOOL SCICPIsTemplateSceneRole(NSString *role) {
    return [role isKindOfClass:NSString.class] &&
           [role isEqualToString:kSCICPTemplateApplicationRole];
}
