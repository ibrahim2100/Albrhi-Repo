#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "SCITWAvatarSave.h"
#import "SCITWMedia.h"
#import "SCITWDownload.h"
#import "Localization/SCILocalize.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// The profile header's own avatar-tap delegate call, asked whether to save instead of
/// only opening the photo.
///
/// `-summaryView:didTapAvatar:menuSource:fromLongPress:` runs whichever way the avatar was
/// reached -- tap or long press -- and `%orig` runs first here so the photo still opens
/// exactly as X intended; this only adds a second action after it, an offer to save.
///
/// `self.account.profileImageMediaEntity` reaches the same `TFSTwitterEntityMedia` class
/// `SCITWMedia itemForEntity:` was written for, so nothing here has to know what shape a
/// media entity is -- it only has to find one.
///

@interface T1ProfileHeaderViewController : UIViewController
- (id)account;
@end

static BOOL sciAvatarClassPresent = NO;

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


%group AvatarSave

%hook T1ProfileHeaderViewController

- (void)summaryView:(id)summaryView
         didTapAvatar:(id)avatarView
           menuSource:(id)menuSource
         fromLongPress:(BOOL)fromLongPress {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefSaveAvatar]) return;

    id account = [self account];
    if (![account respondsToSelector:@selector(profileImageMediaEntity)]) return;

    id entity = ((id (*)(id, SEL))objc_msgSend)(account, @selector(profileImageMediaEntity));
    if (!entity) return;

    SCITWMediaItem *item = [SCITWMedia itemForEntity:entity];
    if (!item) return;

    // A tiny confirm rather than saving in silence: this fires on every tap that opens the
    // photo, including ones that were never about saving it, so the one extra step is what
    // keeps a routine "let me see this bigger" from quietly writing a file every time.
    UIViewController *top = SCITWTopViewController();
    if (!top) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"save_avatar_action")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        [SCITWDownload save:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(top.view.bounds.size.width / 2, top.view.bounds.size.height, 0, 0);

    [top presentViewController:sheet animated:YES completion:nil];
}

%end

%end


NSString *SCITWAvatarSaveReport(void) {
    return sciAvatarClassPresent
        ? @"T1ProfileHeaderViewController hooked"
        : @"T1ProfileHeaderViewController not in this build";
}

void SCITWInstallAvatarSave(void) {
    sciAvatarClassPresent = (NSClassFromString(@"T1ProfileHeaderViewController") != nil);
    if (!sciAvatarClassPresent) {
        SCILogV(@"T1ProfileHeaderViewController not in this build -- no avatar save");
        return;
    }

    %init(AvatarSave);
    SCILogV(@"avatar save attached");
}
