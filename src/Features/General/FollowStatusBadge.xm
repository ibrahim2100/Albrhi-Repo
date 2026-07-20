#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Follow-back badge.
///
/// The IG 410 profile header is Swift, so the relationship is captured from the ObjC
/// avatar image view (`IGProfilePictureImageView`, which exposes -userGQL and renders
/// on the profile page), and the colored pill is placed on the Swift stats container
/// (IGProfileHeaderIdentity.IGProfileHeaderStatButtonContainerView) under the followers
/// stat button (accessibilityIdentifier `user-detail-header-followers`).
///

static const NSInteger SCIFollowBadgeTag = 0x50110B;
static NSString *const SCIFollowersIdentifier = @"user-detail-header-followers";

// Minimum width for the profile-header avatar; smaller ones (bio, highlights, feed)
// are ignored so we only capture the profile owner.
static const CGFloat SCIProfileAvatarMinWidth = 70.0;

// Last user seen on a large IGProfilePictureImageView — the profile header owner.
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

static void SCIRemoveBadge(UIView *container) {
    UIView *badge = [container viewWithTag:SCIFollowBadgeTag];
    if (!badge) badge = [container.window viewWithTag:SCIFollowBadgeTag];
    if (badge) [badge removeFromSuperview];
}

static void SCIUpdateFollowBadge(UIView *container) {
    if (!container) return;
    if (![SCIUtils getBoolPref:@"show_follow_status"]) { SCIRemoveBadge(container); return; }

    // The relationship comes from the avatar hook below — no risky reflection.
    id user = sciProfileUser;
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
