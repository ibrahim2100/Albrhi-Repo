#import "SCIYTNotice.h"
#import "SCIYTJob.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@implementation SCIYTNotice

/// Whether iOS has been asked yet, this launch.
static BOOL sciAsked = NO;

+ (void)post:(NSString *)title body:(NSString *)body {
    if (!SCIPrefEnabled(SCIPrefFinishNotice)) return;

    // Nothing while the app is in front. The Centre's row already says it, and a banner over
    // the screen that is showing you the answer is noise.
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) return;

    UNUserNotificationCenter *centre = [UNUserNotificationCenter currentNotificationCenter];

    void (^deliver)(void) = ^{
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = title;
        content.body = body;
        content.sound = [UNNotificationSound defaultSound];

        // Grouped under one thread, so ten saves finishing overnight are one stack rather
        // than ten separate rows to dismiss.
        content.threadIdentifier = @"com.albrhi.youtube.downloads";

        UNNotificationRequest *request =
            [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                 content:content
                                                 trigger:nil];

        [centre addNotificationRequest:request withCompletionHandler:^(NSError *error) {
            if (error) SCILogV(@"notice: refused — %@", error.localizedDescription);
        }];
    };

    // Asked once, and only when there is something to say.
    //
    // Requesting this at launch would put a permission prompt in front of someone who has
    // not yet asked the tweak for anything -- and a prompt with no context is a prompt that
    // gets refused, which then costs the feature permanently.
    [centre getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            deliver();
            return;
        }

        if (settings.authorizationStatus != UNAuthorizationStatusNotDetermined || sciAsked) {
            return;   // refused before, or already asking
        }

        sciAsked = YES;
        [centre requestAuthorizationWithOptions:UNAuthorizationOptionAlert |
                                                 UNAuthorizationOptionSound
                              completionHandler:^(BOOL granted, NSError *error) {
            if (granted) deliver();
        }];
    }];
}

+ (void)announceFinished:(SCIYTJob *)job {
    [self post:SCILocalized(@"notice_done_title")
          body:[NSString stringWithFormat:SCILocalized(@"notice_done_body"), job.title ?: @""]];
}

+ (void)announceFailed:(SCIYTJob *)job reason:(NSString *)reason {
    [self post:SCILocalized(@"notice_failed_title")
          body:[NSString stringWithFormat:SCILocalized(@"notice_failed_body"),
                job.title ?: @"", reason ?: SCILocalized(@"dl_failed")]];
}

@end
