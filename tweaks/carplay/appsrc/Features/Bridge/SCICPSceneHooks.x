#import "SCICPSceneHooks.h"
#import "SCICPSceneBridge.h"
#import "SCILog.h"
#import <UIKit/UIKit.h>

///
/// Two public UIKit selectors, intercepted for a purpose Apple did not intend: CarPlay
/// builds a scene by asking for one of these two questions, and answering both the
/// same way is what makes an app's own scene delegate take its normal path instead of
/// branching on the CarPlay role it expects never to see. See SCICPSceneBridge.h for
/// why this is safe to install into every app that links UIKit.
///

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

void SCICPInstallSceneHooks(void) {
    %init;
    SCILogV(@"scene: role-rewrite hooks installed");
}
