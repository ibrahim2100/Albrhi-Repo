#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "SCITWAppLock.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Localization/SCILocalize.h"

static BOOL sciDelegatePresent = NO;
static BOOL sciUnlocked = NO;
static BOOL sciAsking = NO;
static NSUInteger sciAsked = 0, sciPassed = 0, sciFailed = 0;
static UIView *sciCover = nil;

static UIWindow *SCIKeyWindow(void) {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) return window;
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

static void SCIRemoveCover(void) {
    [sciCover removeFromSuperview];
    sciCover = nil;
}

static void SCIShowCover(void) {
    UIWindow *window = SCIKeyWindow();
    if (!window || sciCover) return;

    // A solid view rather than a blur: a blur of the timeline is still a picture of the
    // timeline, and the whole point is that nothing of it is on screen.
    sciCover = [[UIView alloc] initWithFrame:window.bounds];
    sciCover.backgroundColor = [UIColor systemBackgroundColor];
    sciCover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UILabel *label = [[UILabel alloc] init];
    label.text = SCILocalized(@"lock_title");
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    label.textColor = [UIColor secondaryLabelColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [sciCover addSubview:label];

    [window addSubview:sciCover];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:sciCover.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:sciCover.centerYAnchor],
    ]];
}

static void SCIAskToUnlock(void) {
    if (sciAsking) return;
    sciAsking = YES;
    sciAsked++;

    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;

    // Biometry *or* passcode. Asking for biometry alone would lock out a phone whose owner
    // has Face ID switched off, and this feature has no business being the reason somebody
    // cannot open an app on their own device.
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        SCILogV(@"app lock: this device cannot authenticate (%@) — letting it through",
                error.localizedDescription ?: @"?");
        sciUnlocked = YES;
        sciAsking = NO;
        SCIRemoveCover();
        return;
    }

    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:SCILocalized(@"lock_reason")
                      reply:^(BOOL success, __unused NSError *evaluateError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            sciAsking = NO;
            if (success) {
                sciUnlocked = YES;
                sciPassed++;
                SCIRemoveCover();
                return;
            }

            // Refused, so the cover stays and the question is asked again on the next
            // activation. Nothing is done to the app itself: a tweak that closed X on a
            // failed check would be deciding something the user did not ask for.
            sciFailed++;
            SCILogV(@"app lock: refused");
        });
    }];
}


%group AppLock

%hook T1AppDelegate

- (void)applicationDidBecomeActive:(id)application {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefAppLock]) {
        sciUnlocked = YES;
        SCIRemoveCover();
        return;
    }
    if (sciUnlocked) return;

    SCIShowCover();
    SCIAskToUnlock();
}

- (void)applicationWillResignActive:(id)application {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefAppLock]) return;

    // Locked again on the way out, and the cover raised here rather than on the way back:
    // the app switcher's snapshot is taken while resigning, so a cover added afterwards
    // would appear in the app and not in the card somebody is scrolling past.
    sciUnlocked = NO;
    SCIShowCover();
}

%end

%end


NSString *SCITWAppLockReport(void) {
    if (!sciDelegatePresent) return @"app lock: T1AppDelegate not in this build";
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefAppLock]) return @"app lock: off";

    return [NSString stringWithFormat:@"app lock: asked %lu, passed %lu, refused %lu",
            (unsigned long)sciAsked, (unsigned long)sciPassed, (unsigned long)sciFailed];
}

void SCITWInstallAppLock(void) {
    sciDelegatePresent = (NSClassFromString(@"T1AppDelegate") != nil);
    if (!sciDelegatePresent) {
        SCILogV(@"app lock: T1AppDelegate not in this build");
        return;
    }

    %init(AppLock);
    SCILogV(@"app lock attached");
}
