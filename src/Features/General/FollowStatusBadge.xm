#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Follow-back badge.
///
/// Shows a colored pill — green "Follows you" / red "Doesn't follow you" — directly
/// under the Followers count on a profile. It resolves the relationship from the
/// ObjC `IGProfilePictureImageView` (reliable) and anchors to the followers stat
/// button, located by its accessibility identifier `user-detail-header-followers`
/// (the profile header itself is Swift and hard to hook).
///
/// The badge only appears when that stat button is on screen, so it never shows on
/// feed/comment avatars, and it is suppressed on your own profile.
///

static const NSInteger SCIFollowBadgeTag = 0x50110B;
static const CGFloat SCIFollowBadgeMinAvatarWidth = 64.0;
static NSString *const SCIFollowersIdentifier = @"user-detail-header-followers";

static UIView *SCIFindViewWithIdentifier(UIView *root, NSString *identifier) {
    if (!root) return nil;
    if ([root.accessibilityIdentifier isEqualToString:identifier]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = SCIFindViewWithIdentifier(sub, identifier);
        if (found) return found;
    }
    return nil;
}

%hook IGProfilePictureImageView

- (void)layoutSubviews {
    %orig;
    [self sci_updateFollowBadge];
}

%new - (void)sci_updateFollowBadge {
    if (![SCIUtils getBoolPref:@"show_follow_status"]) { [self sci_removeFollowBadge]; return; }
    if (self.bounds.size.width < SCIFollowBadgeMinAvatarWidth) { [self sci_removeFollowBadge]; return; }

    IGUser *user = nil;
    @try { user = [self valueForKey:@"userGQL"]; } @catch (__unused id e) {}
    if (!user) { @try { user = [self valueForKey:@"user"]; } @catch (__unused id e) {} }

    if (!user || ![user respondsToSelector:@selector(followsCurrentUser)]) { [self sci_removeFollowBadge]; return; }

    // Never show it on your own profile.
    NSString *me = [SCIUtils currentUsername];
    NSString *them = nil;
    @try { them = [user valueForKey:@"username"]; } @catch (__unused id e) {}
    if (me.length && them.length && [me isEqualToString:them]) { [self sci_removeFollowBadge]; return; }

    BOOL follows = NO;
    @try { follows = [[user valueForKey:@"followsCurrentUser"] boolValue]; } @catch (__unused id e) {}

    // Prefer anchoring under the followers count; if it can't be found, fall back to
    // sitting just below the avatar so the badge never simply vanishes.
    UIView *followersView = self.window ? SCIFindViewWithIdentifier(self.window, SCIFollowersIdentifier) : nil;

    UIView *host;
    CGRect anchorInHost;
    if (followersView && followersView.superview) {
        host = followersView.superview;
        anchorInHost = [followersView convertRect:followersView.bounds toView:host];
    } else {
        host = self.superview;
        if (!host) return;
        anchorInHost = self.frame;
    }

    // Keep the badge from being clipped by a tightly-sized stats container.
    host.clipsToBounds = NO;

    // Reuse an existing badge; if it lives under a different host now, move it.
    UILabel *badge = (UILabel *)(self.window ? [self.window viewWithTag:SCIFollowBadgeTag] : [host viewWithTag:SCIFollowBadgeTag]);
    if (badge && badge.superview != host) { [badge removeFromSuperview]; badge = nil; }

    if (![badge isKindOfClass:[UILabel class]]) {
        badge = [[UILabel alloc] init];
        badge.tag = SCIFollowBadgeTag;
        badge.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
        badge.textColor = [UIColor whiteColor];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.clipsToBounds = YES;
        badge.layer.cornerRadius = 9.0;
        badge.userInteractionEnabled = NO;
        [host addSubview:badge];
    }

    badge.text = follows ? SCILocalized(@"p_follows_you") : SCILocalized(@"p_not_follows_you");
    badge.backgroundColor = follows ? [UIColor systemGreenColor] : [UIColor systemRedColor];

    CGFloat width = badge.intrinsicContentSize.width + 18.0;
    CGFloat height = 18.0;

    badge.frame = CGRectMake(CGRectGetMidX(anchorInHost) - width / 2.0,
                             CGRectGetMaxY(anchorInHost) + 4.0,
                             width, height);

    [host bringSubviewToFront:badge];
}

%new - (void)sci_removeFollowBadge {
    UIWindow *window = self.window;
    UIView *badge = window ? [window viewWithTag:SCIFollowBadgeTag] : [self.superview viewWithTag:SCIFollowBadgeTag];
    if (badge) [badge removeFromSuperview];
}

%end
