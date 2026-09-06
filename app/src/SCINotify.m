#import "SCINotify.h"
#import "SCIAPI.h"
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <BackgroundTasks/BackgroundTasks.h>

/// Declared in Info.plist as well, and the two must match exactly: a task identifier the plist
/// does not list is refused at registration, and the refusal is a thrown exception at launch
/// rather than a returned NO.
static NSString *const kTaskID = @"com.albrhi.licences.refresh";

static NSString *const kOnKey = @"notify-on";
static NSString *const kSeenKey = @"requests-last-seen";

NSString *const SCIRequestsWaitingNotification = @"SCIRequestsWaiting";

@implementation SCINotify

+ (BOOL)isOn {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kOnKey];
}

+ (void)toggle:(void (^)(BOOL, NSString *_Nullable))then {
    if ([self isOn]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kOnKey];
        then(NO, @"أُطفئت الإشعارات");
        return;
    }

    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound
                                | UNAuthorizationOptionBadge
                      completionHandler:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) {
                // Refused in Settings, not here -- so the sentence says where to change it rather
                // than offering a switch that will refuse again.
                then(NO, @"الإشعارات مرفوضة لهذا التطبيق — فعّلها من إعدادات iOS");
                return;
            }

            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kOnKey];
            [self schedule];
            then(YES, @"ستصلك إشعارات عند وصول طلب جديد");
        });
    }];
}

+ (void)registerTask {
    [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:kTaskID
                                                          usingQueue:nil
                                                       launchHandler:^(BGTask *task) {
        // A task that never calls setTaskCompleted: is a task iOS stops scheduling. The expiry
        // handler is not optional either: the system can take the time back at any moment, and an
        // app that does not answer is an app that gets fewer chances next time.
        // Weak in both blocks: a task that holds a block that holds the task is a task the system
        // cannot release, and `-Werror` is right to refuse it.
        __weak BGTask *weakTask = task;

        task.expirationHandler = ^{ [weakTask setTaskCompletedWithSuccess:NO]; };

        [self checkAndNotify:^(BOOL found) {
            [self schedule];
            [weakTask setTaskCompletedWithSuccess:YES];
        }];
    }];
}

+ (void)schedule {
    if (![self isOn]) return;

    BGAppRefreshTaskRequest *request =
        [[BGAppRefreshTaskRequest alloc] initWithIdentifier:kTaskID];

    // Fifteen minutes is the earliest iOS will consider, not a promise of fifteen minutes. Asking
    // for less does not make it sooner; it only makes the request look untrue.
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15 * 60];

    NSError *error = nil;
    [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
}

+ (void)checkAndNotify:(void (^)(BOOL))then {
    if (![SCIAPI isConfigured]) { if (then) then(NO); return; }

    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error || ![state[@"requests"] isKindOfClass:[NSArray class]]) {
            if (then) then(NO);
            return;
        }

        NSUInteger waiting = [state[@"requests"] count];
        NSUInteger seen = [[NSUserDefaults standardUserDefaults] integerForKey:kSeenKey];

        // The badge is set either way -- it is a count, and a count that only ever grows is a lie
        // the moment a request is answered from somewhere else.
        [UIApplication sharedApplication].applicationIconBadgeNumber = (NSInteger)waiting;
        [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)waiting forKey:kSeenKey];

        [[NSNotificationCenter defaultCenter] postNotificationName:SCIRequestsWaitingNotification
                                                            object:@(waiting)];

        // **More than last time, not "any at all".** A notification for a request that has been
        // sitting there since yesterday is a notification that teaches somebody to ignore them.
        if (waiting <= seen || ![self isOn]) { if (then) then(NO); return; }

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = @"طلب ترخيص جديد";
        content.body = waiting == 1 ? @"طلبٌ واحد ينتظر الردّ"
                                    : [NSString stringWithFormat:@"%lu طلبات تنتظر الردّ",
                                       (unsigned long)waiting];
        content.sound = [UNNotificationSound defaultSound];
        content.badge = @(waiting);

        UNNotificationRequest *notification =
            [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                 content:content
                                                 trigger:nil];   // now

        [[UNUserNotificationCenter currentNotificationCenter]
            addNotificationRequest:notification withCompletionHandler:nil];

        if (then) then(YES);
    }];
}

@end
