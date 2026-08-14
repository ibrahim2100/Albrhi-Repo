#import "SCICPSceneHooks.h"
#import "SCICPSceneBridge.h"
#import "SCILog.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

///
/// Two public UIKit selectors, intercepted for a purpose Apple did not intend: CarPlay
/// builds a scene by asking for one of these two questions, and answering both the
/// same way is what makes an app's own scene delegate take its normal path instead of
/// branching on the CarPlay role it expects never to see. See SCICPSceneBridge.h for
/// why this is safe to install into every app that links UIKit.
///
/// A third, private one is hooked below the %hook groups: most apps declare a scene
/// manifest (Xcode has defaulted to one since iOS 13) without ever opting into
/// `UIApplicationSupportsMultipleScenes` -- almost nothing needs a second window on
/// the phone itself. Left alone, that is why bridging looked like it worked and did
/// not: the phone scene and the car scene cannot coexist, so instead of a second,
/// independent scene the app's *existing* session is the one CarPlay connects,
/// which is the exact "now it only runs in the car, and the phone can't open it"
/// behaviour reported from a real device.

%hook UISceneConfiguration

- (instancetype)initWithName:(NSString *)name sessionRole:(NSString *)sessionRole {
    if (!SCICPIsTemplateSceneRole(sessionRole) || !SCICPSceneBridgeEnabledForThisApp()) {
        return %orig;
    }

    SCILogV(@"scene: rewriting configuration role %@ (name %@) -> %@", sessionRole,
            name.length ? name : @"(default)", UIWindowSceneSessionRoleApplication);

    // The configuration name would be a CarPlay-specific one the app's own Info.plist
    // does not contain; nil asks UIKit for the default configuration of the rewritten
    // role instead of a lookup that would fail to find anything.
    UISceneConfiguration *configuration = %orig(nil, UIWindowSceneSessionRoleApplication);

    // Belt and braces: pin the scene class too, so UIKit cannot fall back to a
    // template scene even if something upstream still thinks this is a CarPlay role.
    if ([configuration respondsToSelector:@selector(setSceneClass:)]) {
        configuration.sceneClass = UIWindowScene.class;
    }
    return configuration;
}

%end

%hook UISceneSession

- (NSString *)role {
    NSString *role = %orig;
    if (!SCICPIsTemplateSceneRole(role) || !SCICPSceneBridgeEnabledForThisApp()) {
        return role;
    }

    SCILogV(@"scene: rewriting session role %@ -> %@", role, UIWindowSceneSessionRoleApplication);
    return UIWindowSceneSessionRoleApplication;
}

%end

#pragma mark - Multi-scene support

// UIApplicationSceneManifest is private, so this is a guarded manual swizzle rather
// than a %hook -- the same reason SCICPAdmissionSpoof.m hooks LSBundleProxy by hand:
// a selector this iOS build renamed must degrade to "not forced", never a crash.

static BOOL SCICPSwizzleInstanceMethod(Class cls, SEL sel, IMP replacement, IMP *outOriginal) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return NO;

    if (outOriginal) *outOriginal = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}

static BOOL (*sciOrigSupportsMultipleScenes)(id, SEL);

static BOOL sciSupportsMultipleScenes(id self, SEL _cmd) {
    if (!SCICPSceneBridgeEnabledForThisApp()) return sciOrigSupportsMultipleScenes(self, _cmd);
    return YES;
}

static void SCICPInstallMultiSceneForce(void) {
    Class manifest = NSClassFromString(@"UIApplicationSceneManifest");
    BOOL installed = SCICPSwizzleInstanceMethod(
        manifest, sel_getUid("supportsMultipleScenes"),
        (IMP)sciSupportsMultipleScenes, (IMP *)&sciOrigSupportsMultipleScenes);

    SCILogV(@"scene: multi-scene force %@", installed ? @"installed" : @"unavailable "
            "on this build — a bridged app may still only run in the car, not both");
}

void SCICPInstallSceneHooks(void) {
    %init;
    SCICPInstallMultiSceneForce();
    SCILogV(@"scene: role-rewrite hooks installed");
}
