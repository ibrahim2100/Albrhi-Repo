#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "SCIPages.h"
#import "SCIAPI.h"
#import "SCINotify.h"

//
// **The whole app: a tab bar, seven pages and a lock.**
//
// No storyboard, and none is missing — a storyboard here would describe a tab bar with five items,
// which is fifteen lines of code and one more file that can fail to load on a device where nobody
// can attach a debugger.
//
// **Five tabs, because a sixth is not a tab.** A UITabBarController on an iPhone shows five and
// folds everything after them into a "More" list — so the first version's seven put Stores, Codes
// and Settings behind a grey table nobody would think to open, and measuring it in the simulator
// is what showed that rather than a report weeks later. The two that came out are reached from the
// page they belong to: Codes from Licences, since a code is a licence waiting to be redeemed, and
// Settings from the front page.
//
// The lock is the reason this is an app rather than a bookmark. The admin token can revoke every
// licence sold, so the screen is covered the moment the app leaves the foreground and Face ID is
// asked for on the way back — not once per launch, which would leave a phone in somebody else's
// hand unlocked for as long as the app stays in memory.
//
@interface SCIAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *shield;
@property (nonatomic, assign) BOOL unlocked;
@property (nonatomic, weak) UITabBarController *tabs;
@end

@implementation SCIAppDelegate

- (UINavigationController *)page:(SCIPage *)page symbol:(NSString *)symbol {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
    nav.navigationBar.prefersLargeTitles = YES;
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:page.title
                                                    image:[UIImage systemImageNamed:symbol]
                                                      tag:0];
    return nav;
}

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)options {

    // Registered before the launch finishes, because iOS refuses the identifier afterwards -- and
    // refuses it by throwing, at launch, which is the worst way to find out.
    [SCINotify registerTask];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[
        [self page:[[SCISummaryPage alloc] init]  symbol:@"square.grid.2x2"],
        [self page:[[SCIRequestsPage alloc] init] symbol:@"tray.and.arrow.down"],
        [self page:[[SCILicencesPage alloc] init] symbol:@"key"],
        [self page:[[SCIDevicesPage alloc] init]  symbol:@"iphone"],
        [self page:[[SCIStoresPage alloc] init]   symbol:@"bag"],
    ];

    // The badge on Requests, kept by whoever last asked the server -- the page itself may never
    // have been built.
    self.tabs = tabs;
    [[NSNotificationCenter defaultCenter] addObserverForName:SCIRequestsWaitingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        NSInteger waiting = [note.object integerValue];
        UIViewController *requests = self.tabs.viewControllers[1];
        requests.tabBarItem.badgeValue =
            waiting ? [NSString stringWithFormat:@"%ld", (long)waiting] : nil;
    }];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];

    // Up before anything is drawn. A panel that appears for a moment and is then covered has
    // already shown a customer list to whoever was looking.
    [self raiseShield];
    [self unlock];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self raiseShield];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (!self.unlocked) [self unlock];
    [SCINotify checkAndNotify:nil];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [SCINotify schedule];
}

- (void)raiseShield {
    self.unlocked = NO;

    if (!self.shield) {
        self.shield = [[UIView alloc] initWithFrame:self.window.bounds];
        self.shield.autoresizingMask = UIViewAutoresizingFlexibleWidth
                                     | UIViewAutoresizingFlexibleHeight;
        self.shield.backgroundColor = [UIColor systemBackgroundColor];

        UILabel *name = [[UILabel alloc] initWithFrame:self.shield.bounds];
        name.text = @"تراخيص البرهي";
        name.textAlignment = NSTextAlignmentCenter;
        name.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
        name.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
        [self.shield addSubview:name];

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unlock)];
        [self.shield addGestureRecognizer:tap];
    }

    self.shield.frame = self.window.bounds;
    [self.window addSubview:self.shield];
}

- (void)unlock {
    LAContext *context = [[LAContext alloc] init];

    NSError *error = nil;
    // Device passcode counts, not biometry alone: a face unrecognised in the dark must not lock
    // somebody out of their own licences.
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        // No passcode at all means there is nothing to check against, and a lock with no key is
        // a screen that can never be opened. It comes down, which is the honest behaviour.
        [self lower];
        return;
    }

    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:@"لفتح لوحة التراخيص"
                      reply:^(BOOL success, __unused NSError *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (success) [self lower]; });
    }];
}

- (void)lower {
    self.unlocked = YES;
    [self.shield removeFromSuperview];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SCIAppDelegate class]));
    }
}
