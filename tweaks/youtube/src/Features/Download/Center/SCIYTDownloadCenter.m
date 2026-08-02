#import "SCIYTDownloadCenter.h"
#import "SCIYTDownloadList.h"
#import "SCIYTLibrary.h"
#import "../../../SCILog.h"
#import "../../../Localization/SCILocalize.h"

static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

@implementation SCIYTDownloadCenter

+ (void)present {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    // Wrapped, the way the settings panel is. A screen of ours failing to build must be
    // a screen that does not open, never a crash inside YouTube.
    @try {
        [top presentViewController:[self build] animated:YES completion:nil];
    } @catch (NSException *exception) {
        SCILogV(@"centre: could not open — %@", exception.reason);
    }
}

/// Video and sound, each with its own tab.
///
/// A real tab bar rather than a filter above one list: they are two different things to
/// look at, and a row sized to hold a still is the wrong row for a song. Each list is in
/// its own navigation controller so each keeps its own title and its own Done button --
/// one shared bar would put the wrong title over whichever tab was open.
+ (UIViewController *)build {
    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.modalPresentationStyle = UIModalPresentationPageSheet;
    tabs.tabBar.tintColor = SCIAccent();

    NSMutableArray<UIViewController *> *pages = [NSMutableArray array];
    for (NSNumber *kind in @[@(SCIYTJobKindVideo), @(SCIYTJobKindAudio)]) {
        SCIYTDownloadList *list =
            [[SCIYTDownloadList alloc] initWithKind:(SCIYTJobKind)kind.integerValue];

        UINavigationController *page =
            [[UINavigationController alloc] initWithRootViewController:list];
        page.tabBarItem = list.tabBarItem;

        // Done belongs to the list and dismisses the list.
        //
        // Not a category on UIViewController, which was the first shape of this and a
        // bad one: a category adds its method to *every* view controller in YouTube's
        // process, and a name that collides with one of theirs replaces it silently.
        // UIKit already forwards a dismissal up from a presented controller to whatever
        // presented it, so the list asking to be dismissed closes the whole sheet.
        list.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                           target:list
                                                           action:@selector(close)];
        [pages addObject:page];
    }

    tabs.viewControllers = pages;
    return tabs;
}

@end
