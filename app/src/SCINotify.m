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

/// The day a licence was last mentioned, keyed by device. **Once per licence per day, not once
/// per check**: the background refresh runs whenever iOS feels like it, and a reminder that
/// arrives six times about the same person is a reminder that gets switched off.
static NSString *const kToldKey = @"expiry-told";

/// A week, which is the whole point of the reminder: it is long enough to have the conversation
/// and short enough that the answer is still "renew" rather than "I stopped using it".
static const NSTimeInterval kSoon = 7 * 86400;

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

/// Licences ending within the week, said once a day and by name.
///
/// **Named, not counted.** "Three licences end this week" is a number to go and look up; the
/// person's own name is the message, because the next step after reading it is opening WhatsApp
/// and typing that name.
+ (void)noticeExpiring:(id)licences {
    if (![self isOn] || ![licences isKindOfClass:[NSArray class]]) return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *told = [([defaults dictionaryForKey:kToldKey] ?: @{}) mutableCopy];

    double now = [NSDate date].timeIntervalSince1970;
    double today = floor(now / 86400);

    for (NSDictionary *licence in licences) {
        if (![licence isKindOfClass:[NSDictionary class]]) continue;
        if ([licence[@"revoked"] boolValue]) continue;

        double until = [licence[@"until"] doubleValue];
        if (until <= 0 || until < now || until > now + kSoon) continue;   // lifetime, gone, or far

        NSString *device = licence[@"key"] ?: licence[@"dev"];
        if (!device.length) continue;
        if ([told[device] doubleValue] == today) continue;

        told[device] = @(today);

        NSInteger days = (NSInteger)ceil((until - now) / 86400.0);
        NSString *who = [licence[@"name"] length] ? licence[@"name"] : device;

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = @"ترخيص ينتهي قريباً";
        content.body = days <= 1
            ? [NSString stringWithFormat:@"ترخيص %@ ينتهي اليوم", who]
            : [NSString stringWithFormat:@"ترخيص %@ ينتهي خلال %ld أيام", who, (long)days];
        content.sound = [UNNotificationSound defaultSound];

        [[UNUserNotificationCenter currentNotificationCenter]
            addNotificationRequest:[UNNotificationRequest
                requestWithIdentifier:[@"expiry-" stringByAppendingString:device]
                              content:content trigger:nil]
             withCompletionHandler:nil];
    }

    // Devices no longer expiring are forgotten, or this dictionary grows for the life of the app
    // and a renewed licence could never be reminded about again.
    NSMutableDictionary *kept = [NSMutableDictionary dictionary];
    for (NSDictionary *licence in licences) {
        NSString *device = [licence isKindOfClass:[NSDictionary class]]
            ? (licence[@"key"] ?: licence[@"dev"]) : nil;
        if (device.length && told[device]) kept[device] = told[device];
    }
    [defaults setObject:kept forKey:kToldKey];
}

/// The three numbers the home screen shows, left in the shared container.
///
/// **The widget is never given the token.** An extension is a second process iOS launches on its
/// own schedule, and a token that can revoke every licence sold has no business being reachable
/// from one — so the app does the asking and the widget reads a file with nothing secret in it.
/// Nothing here fails loudly: without the app group the container is nil, and the widget says the
/// app has not been opened yet, which is exactly what is true.
+ (void)writeCounts:(NSDictionary *)state {
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:@"group.com.albrhi.licences"];
    if (!container) return;

    id licences = state[@"licences"];
    if (![licences isKindOfClass:[NSArray class]]) licences = @[];

    double now = [NSDate date].timeIntervalSince1970;
    NSUInteger live = 0, soon = 0;

    for (NSDictionary *licence in licences) {
        if (![licence isKindOfClass:[NSDictionary class]]) continue;
        if ([licence[@"revoked"] boolValue]) continue;

        double until = [licence[@"until"] doubleValue];
        if (until != 0 && until <= now) continue;

        live++;
        if (until > 0 && until < now + 14 * 86400) soon++;
    }

    NSDictionary *counts = @{@"waiting": @([state[@"requests"] count]),
                             @"live": @(live), @"soon": @(soon),
                             @"at": @(now)};

    NSData *data = [NSJSONSerialization dataWithJSONObject:counts options:0 error:NULL];
    [data writeToURL:[container URLByAppendingPathComponent:@"counts.json"] atomically:YES];
}

+ (void)checkAndNotify:(void (^)(BOOL))then {
    if (![SCIAPI isConfigured]) { if (then) then(NO); return; }

    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error || ![state[@"requests"] isKindOfClass:[NSArray class]]) {
            if (then) then(NO);
            return;
        }

        [self noticeExpiring:state[@"licences"]];
        [self writeCounts:state];

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
