#import <UIKit/UIKit.h>

//
// The whole of the app's startup: one window, one view controller.
//
// No storyboard, and none is missing: a storyboard here would be a file describing a single
// full-screen view, which is four lines of code and one more thing that can fail to load.
//
@interface SCIAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface SCIPanelViewController : UIViewController
@end

@implementation SCIAppDelegate

- (BOOL)application:(__unused UIApplication *)application
        didFinishLaunchingWithOptions:(__unused NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[[SCIPanelViewController alloc] init]];
    nav.navigationBarHidden = YES;

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SCIAppDelegate class]));
    }
}
