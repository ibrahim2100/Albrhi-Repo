#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"
#import <objc/runtime.h>

///
/// Follow-back badge.
///
/// The IG 410 profile header is entirely Swift (the avatar is
/// IGProfileHeaderIdentityAvatarView, not IGProfilePictureImageView), so this hooks
/// the Swift stats container — IGProfileHeaderIdentity.IGProfileHeaderStatButtonContainerView —
/// and drops a colored pill under the followers stat button
/// (accessibilityIdentifier `user-detail-header-followers`).
///
/// The follow relationship needs an IGUser (`followsCurrentUser`); it's found by
/// walking the responder chain to the profile view controller and doing a bounded,
/// guarded reflective search of its object ivars.
///

static const NSInteger SCIFollowBadgeTag = 0x50110B;
static NSString *const SCIFollowersIdentifier = @"user-detail-header-followers";
static const void *kSCIProfileUserKey = &kSCIProfileUserKey;

// Minimum width for the profile-header avatar; smaller ones (bio, highlights, feed)
// are ignored so we only capture the profile owner.
static const CGFloat SCIProfileAvatarMinWidth = 70.0;

// Last user seen on a large IGProfilePictureImageView — the profile header owner.
// IGProfilePictureImageView reliably exposes -userGQL and does render on the profile
// page (the Swift avatar wraps it), so it's the dependable source of the relationship
// even though the badge itself is placed on the Swift stats container.
static id sciProfileUser = nil;

static UIView *SCIFindViewWithIdentifier(UIView *root, NSString *identifier) {
    if (!root) return nil;
    if ([root.accessibilityIdentifier isEqualToString:identifier]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = SCIFindViewWithIdentifier(sub, identifier);
        if (found) return found;
    }
    return nil;
}

static BOOL SCILooksLikeUser(id obj) {
    if (!obj) return NO;
    @try {
        return [obj respondsToSelector:@selector(followsCurrentUser)]
            && [obj respondsToSelector:@selector(username)];
    } @catch (__unused id e) {}
    return NO;
}

// Bounded, guarded reflective search for an IGUser inside an object's ivars.
static id SCIUserInObject(id obj, int depth) {
    if (!obj || depth > 2) return nil;
    if (SCILooksLikeUser(obj)) return obj;

    Class cls = object_getClass(obj);
    int classGuard = 0;

    while (cls && cls != [NSObject class] && classGuard++ < 6) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);

        for (unsigned int i = 0; i < count; i++) {
            const char *type = ivar_getTypeEncoding(ivars[i]);
            if (!type || type[0] != '@') continue;   // object ivars only

            id value = nil;
            @try { value = object_getIvar(obj, ivars[i]); } @catch (__unused id e) { continue; }
            if (!value) continue;

            // Don't descend into views/collections/leaves — keeps it fast and safe.
            if ([value isKindOfClass:[UIView class]] || [value isKindOfClass:[UIViewController class]]
             || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]
             || [value isKindOfClass:[NSSet class]] || [value isKindOfClass:[NSString class]]
             || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSData class]]) {
                continue;
            }

            if (SCILooksLikeUser(value)) { free(ivars); return value; }

            id nested = SCIUserInObject(value, depth + 1);
            if (nested) { free(ivars); return nested; }
        }

        free(ivars);
        cls = class_getSuperclass(cls);
    }
    return nil;
}

static id SCIProfileUserFromView(UIView *view) {
    UIResponder *responder = view;
    int steps = 0;
    while (responder && steps++ < 25) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            id user = SCIUserInObject(responder, 0);
            if (user) return user;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

static void SCIRemoveBadge(UIView *container) {
    UIView *badge = [container viewWithTag:SCIFollowBadgeTag];
    if (!badge) badge = [container.window viewWithTag:SCIFollowBadgeTag];
    if (badge) [badge removeFromSuperview];
}

static void SCIUpdateFollowBadge(UIView *container) {
    if (!container) return;
    if (![SCIUtils getBoolPref:@"show_follow_status"]) { SCIRemoveBadge(container); return; }

    // Prefer the user captured from the profile-header avatar; fall back to a cached
    // reflective lookup, then a fresh one.
    id user = SCILooksLikeUser(sciProfileUser) ? sciProfileUser : nil;
    if (!user) user = objc_getAssociatedObject(container, kSCIProfileUserKey);
    if (!SCILooksLikeUser(user)) {
        user = SCIProfileUserFromView(container);
        if (user) objc_setAssociatedObject(container, kSCIProfileUserKey, user, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!SCILooksLikeUser(user)) { SCIRemoveBadge(container); return; }

    // Never on your own profile.
    NSString *me = [SCIUtils currentUsername];
    NSString *them = nil;
    @try { them = [user valueForKey:@"username"]; } @catch (__unused id e) {}
    if (me.length && them.length && [me isEqualToString:them]) { SCIRemoveBadge(container); return; }

    BOOL follows = NO;
    @try { follows = [[user valueForKey:@"followsCurrentUser"] boolValue]; } @catch (__unused id e) {}

    // Anchor under the followers stat button; the container is its parent.
    UIView *followers = SCIFindViewWithIdentifier(container, SCIFollowersIdentifier) ?: container;

    container.clipsToBounds = NO;

    UILabel *badge = (UILabel *)[container viewWithTag:SCIFollowBadgeTag];
    if (![badge isKindOfClass:[UILabel class]]) {
        badge = [[UILabel alloc] init];
        badge.tag = SCIFollowBadgeTag;
        badge.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
        badge.textColor = [UIColor whiteColor];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.clipsToBounds = YES;
        badge.layer.cornerRadius = 9.0;
        badge.userInteractionEnabled = NO;
        [container addSubview:badge];
    }

    badge.text = follows ? SCILocalized(@"p_follows_you") : SCILocalized(@"p_not_follows_you");
    badge.backgroundColor = follows ? [UIColor systemGreenColor] : [UIColor systemRedColor];

    CGFloat width = badge.intrinsicContentSize.width + 18.0;
    CGFloat height = 18.0;

    CGRect anchor = [followers convertRect:followers.bounds toView:container];
    badge.frame = CGRectMake(CGRectGetMidX(anchor) - width / 2.0,
                             CGRectGetMaxY(anchor) + 4.0,
                             width, height);

    [container bringSubviewToFront:badge];
}

// Capture the profile owner from the (ObjC) avatar image view — reliable source of
// -userGQL — but only from the large header avatar, so bio/highlight/feed thumbnails
// don't pollute it.
%hook IGProfilePictureImageView

- (void)layoutSubviews {
    %orig;

    if (![SCIUtils getBoolPref:@"show_follow_status"]) return;
    if (self.bounds.size.width < SCIProfileAvatarMinWidth) return;

    id user = nil;
    @try { user = [self valueForKey:@"userGQL"]; } @catch (__unused id e) {}
    if (!user) { @try { user = [self valueForKey:@"user"]; } @catch (__unused id e) {} }

    if (SCILooksLikeUser(user)) sciProfileUser = user;
}

%end

// Place the badge under the followers count on the profile page (the stats row is Swift).
%hook IGProfileHeaderIdentity.IGProfileHeaderStatButtonContainerView

- (void)layoutSubviews {
    %orig;
    SCIUpdateFollowBadge((UIView *)self);
}

%end
