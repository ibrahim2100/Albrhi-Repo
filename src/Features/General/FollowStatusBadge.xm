#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Follow-back badge.
///
/// Overlays a small colored pill on the large profile-header avatar: green
/// "Follows you" when the account follows you, red "Doesn't follow you" when it
/// doesn't — visible directly on the profile, no long-press required.
///
/// It attaches to the avatar's superview (not the avatar itself, which is clipped
/// to a circle) and only to profile-sized avatars, so feed/comment thumbnails stay
/// untouched. It is suppressed on your own profile.
///

static const NSInteger SCIFollowBadgeTag = 0x50110B;

// Below this width the view is a thumbnail (feed, comments, story ring), not the
// profile header — don't badge those.
static const CGFloat SCIFollowBadgeMinAvatarWidth = 70.0;

%hook IGProfilePictureImageView

- (void)layoutSubviews {
    %orig;
    [self sci_updateFollowBadge];
}

%new - (void)sci_updateFollowBadge {
    if (![SCIUtils getBoolPref:@"show_follow_status"]) { [self sci_removeFollowBadge]; return; }
    if (self.bounds.size.width < SCIFollowBadgeMinAvatarWidth) { [self sci_removeFollowBadge]; return; }

    UIView *host = self.superview;
    if (!host) return;

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

    UILabel *badge = (UILabel *)[host viewWithTag:SCIFollowBadgeTag];
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

    CGFloat width = badge.intrinsicContentSize.width + 20.0;
    CGFloat height = 18.0;

    // Sit centered fully below the avatar, in the host's coordinate space — this
    // lands in the stats/name area, roughly under the followers count.
    CGRect avatarInHost = [self convertRect:self.bounds toView:host];
    CGRect frame = CGRectMake(CGRectGetMidX(avatarInHost) - width / 2.0,
                              CGRectGetMaxY(avatarInHost) + 6.0,
                              width, height);
    badge.frame = frame;

    [host bringSubviewToFront:badge];
}

%new - (void)sci_removeFollowBadge {
    UIView *host = self.superview;
    UIView *badge = [host viewWithTag:SCIFollowBadgeTag];
    if (badge) [badge removeFromSuperview];
}

%end
