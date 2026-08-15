#import <objc/message.h>
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

///
/// Finds the profile's user by asking for one **confirmed** selector, and never by KVC.
///
/// What was here before probed twelve speculative keys -- user, currentUser, displayedUser,
/// profileUser, owner, account, viewModel, userDetailViewModel, model, headerViewModel,
/// header, dataSource -- with -valueForKey:, on every object up the responder chain, two
/// levels deep, from inside -layoutSubviews. Its own comment claimed that was safe because
/// "a missing key just throws (caught)".
///
/// **That is not what -valueForKey: does.** It calls the real getter when one exists, and
/// falls back to reading the ivar directly; raising is only the last resort. So each of
/// those keys was *executing Instagram's code* -- `dataSource` on a collection view, and
/// `account` on Instagram's own objects, being the two worth naming -- dozens of times a
/// second while the screen was being rebuilt.
///
/// And @catch does not make that safe. It catches NSException. A Swift getter that traps, a
/// failed assertion, or a half-initialised object are not exceptions; they end the process
/// and no handler sees them. Changing a profile picture is exactly when those models are
/// mid-replacement, which is the crash that was reported.
///
/// So: no KVC anywhere in this file's lookup. `-userGQL` is confirmed present on
/// IGProfilePictureImageView in a class dump of this build, it is guarded by
/// -respondsToSelector: before it is ever sent, and objects that do not answer it are
/// stepped over rather than interrogated. The responder walk is kept, because it is what
/// makes the badge correct on the *current* profile rather than the last one captured --
/// it is only what the walk asks that changed.
///
static id SCIUserFromObject(id obj) {
    if (!obj) return nil;
    if (SCILooksLikeUser(obj)) return obj;

    SEL userGQL = @selector(userGQL);
    if (![obj respondsToSelector:userGQL]) return nil;

    id user = ((id (*)(id, SEL))objc_msgSend)(obj, userGQL);
    return SCILooksLikeUser(user) ? user : nil;
}

static id SCIProfileUserFromResponder(UIView *view) {
    UIResponder *responder = view;
    int steps = 0;
    while (responder && steps++ < 25) {
        id user = SCIUserFromObject(responder);
        if (user) return user;
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

    // Primary: read the profile VC's user via safe KVC. Fallback: the user captured
    // from the header avatar's -userGQL.
    id user = SCIProfileUserFromResponder(container);
    if (!SCILooksLikeUser(user)) user = sciProfileUser;
    if (!SCILooksLikeUser(user)) { SCIRemoveBadge(container); return; }

    // Never on your own profile.
    NSString *me = [SCIUtils currentUsername];
    // Sent directly, not through KVC: SCILooksLikeUser has already proved both selectors
    // exist on this object, so there is nothing KVC would add but another code path.
    NSString *them = ((NSString *(*)(id, SEL))objc_msgSend)(user, @selector(username));
    if (me.length && them.length && [me isEqualToString:them]) { SCIRemoveBadge(container); return; }

    BOOL follows = ((BOOL (*)(id, SEL))objc_msgSend)(user, @selector(followsCurrentUser));

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

    // -userGQL only. "user" is not on this class at all -- confirmed absent in the class
    // dump -- so asking for it raised an exception on every single layout pass and could
    // never have returned anything.
    id user = SCIUserFromObject(self);
    if (user) sciProfileUser = user;
}

%end

// Place the badge under the followers count on the profile page (the stats row is Swift).
%hook IGProfileHeaderIdentity.IGProfileHeaderStatButtonContainerView

- (void)layoutSubviews {
    %orig;
    SCIUpdateFollowBadge((UIView *)self);
}

%end
