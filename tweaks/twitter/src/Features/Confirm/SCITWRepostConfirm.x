#import <UIKit/UIKit.h>
#import "SCITWRepostConfirm.h"
#import "Localization/SCILocalize.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// One confirmation, on the one button that needed it.
///
/// `-didTap` is declared on `TTAStatusInlineActionButton`, the base every inline action
/// button shares -- like, bookmark, retweet, share -- and inherited rather than overridden
/// by most of them. Hooking it on the *subclass name* `TTAStatusInlineRetweetButton` still
/// only fires for a retweet button: Substrate resolves and replaces the implementation that
/// class actually runs, inherited or not, and hooking the concrete subclass rather than the
/// shared base is what keeps this off the like and bookmark buttons without needing to know
/// which private enum value `-inlineActionType` uses for "retweet" -- a number nothing in
/// this class dump names.
///
/// ## Deferred, not skipped
///
/// `%orig` is a stand-in for the original `-didTap`, and it still works from inside a block
/// declared within this method's body -- the pointer it expands to is a file-scope symbol,
/// not something that goes out of scope when the method returns. So the tap is not
/// swallowed and re-synthesized; the same call X's own button would have made is simply
/// held until the alert's own handler runs it.
///

@interface TTAStatusInlineFavoriteButton : UIControl
@end

@interface TUIFollowControl : UIControl
@end

@interface TTAStatusInlineRetweetButton : UIControl
@end

static BOOL sciRepostClassPresent = NO;
static BOOL sciLikeClassPresent = NO;
static BOOL sciFollowClassPresent = NO;

/// Where to put the alert: the top of whatever is currently on screen, the same search
/// every screen-presenting feature in this tweak already uses.
static UIViewController *SCITWTopViewController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) window = candidate;
        }
    }
    if (!window) return nil;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}


%group RepostConfirm

%hook TTAStatusInlineRetweetButton

- (void)didTap {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefConfirmRepost]) {
        %orig;
        return;
    }

    UIViewController *top = SCITWTopViewController();
    if (!top) {
        // No screen to ask on beats a repost nobody agreed to -- the tap is dropped
        // rather than let through unconfirmed, which would be the one outcome worse
        // than either alternative.
        SCILogV(@"repost confirm: no view controller to present on, dropping the tap");
        return;
    }

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"repost_confirm_action")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            %orig;
        }
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    // Required on iPad, where an action sheet with nothing to point at is not shown at
    // all rather than being shown badly.
    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;

    [top presentViewController:sheet animated:YES completion:nil];
}

%end

%end


%group LikeConfirm

%hook TTAStatusInlineFavoriteButton

/// The like button's tap, confirmed the same way the repost's is.
///
/// `-didTap` is declared on the shared base `TTAStatusInlineActionButton` and not on this
/// subclass, which is the safe half of the rule CLAUDE.md states: hooking an *inherited*
/// method is fine because `%orig` resolves to the superclass's real implementation. What is
/// never safe is hooking a method no class in the chain implements at all.
- (void)didTap {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefConfirmLike]) {
        %orig;
        return;
    }

    // Already liked, so this tap is an *un*like -- and nobody asked to be protected from
    // taking a like back. Asked of the button rather than of the model, because the button
    // is the thing whose selected state X keeps in step with what is drawn.
    if (self.selected) {
        %orig;
        return;
    }

    UIViewController *top = SCITWTopViewController();
    if (!top) {
        SCILogV(@"like confirm: no view controller to present on, dropping the tap");
        return;
    }

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"like_confirm_action")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            %orig;
        }
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;

    [top presentViewController:sheet animated:YES completion:nil];
}

%end

%end


%group FollowConfirm

%hook TUIFollowControl

/// Following, confirmed. **Unfollowing is not**, and that asymmetry is the same one the
/// like confirmation makes: `-_unfollowUser:event:` is left alone, because nobody asked to
/// be protected from taking a follow back.
///
/// The arguments are passed through untouched rather than reconstructed -- `sender` and
/// `event` are X's own, and re-sending them is what makes the confirmed path identical to
/// the unconfirmed one.
- (void)_followUser:(id)sender event:(id)event {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefConfirmFollow]) {
        %orig;
        return;
    }

    UIViewController *top = SCITWTopViewController();
    if (!top) {
        SCILogV(@"follow confirm: no view controller to present on, dropping the tap");
        return;
    }

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"follow_confirm_action")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            %orig;
        }
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;

    [top presentViewController:sheet animated:YES completion:nil];
}

%end

%end


NSString *SCITWRepostConfirmReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:sciRepostClassPresent ? @"repost hooked" : @"repost class absent"];
    [parts addObject:sciLikeClassPresent ? @"like hooked" : @"like class absent"];
    [parts addObject:sciFollowClassPresent ? @"follow hooked" : @"follow class absent"];
    return [parts componentsJoinedByString:@" · "];
}

void SCITWInstallRepostConfirm(void) {
    sciRepostClassPresent = (NSClassFromString(@"TTAStatusInlineRetweetButton") != nil);
    if (!sciRepostClassPresent) {
        SCILogV(@"TTAStatusInlineRetweetButton not in this build -- no repost confirmation");
        return;
    }

    %init(RepostConfirm);
    SCILogV(@"repost confirmation attached");

    sciLikeClassPresent = (NSClassFromString(@"TTAStatusInlineFavoriteButton") != nil);
    if (sciLikeClassPresent) {
        %init(LikeConfirm);
        SCILogV(@"like confirmation attached");
    }

    sciFollowClassPresent = (NSClassFromString(@"TUIFollowControl") != nil);
    if (sciFollowClassPresent) {
        %init(FollowConfirm);
        SCILogV(@"follow confirmation attached");
    }
}
