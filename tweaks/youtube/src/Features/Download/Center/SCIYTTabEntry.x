#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCIYTDownloadCenter.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"

///
/// The way into the Download Centre from the tab bar, beside You.
///
/// **No YouTube class is named in the hook.** The hook is on UIViewController, which is
/// UIKit and cannot be missing or renamed, and the tab bar is then recognised by what its
/// class is called at runtime. That is the same discipline the settings entry follows and
/// it exists for the same measured reason: a survey of the tweak this project studied for
/// hook points found nineteen of its target view classes absent from this build. Naming
/// one in a %hook makes the whole file's fate depend on a guess.
///
/// Recognised rather than assumed also means the failure is soft. If no controller here
/// is called anything like a pivot bar, no button appears and everything else works
/// exactly as before -- the panel still opens the centre, and the two-finger press still
/// opens the panel. A missing button is a missing button, not a missing tweak.
///

@interface SCIYTTabButtonTarget : NSObject
+ (instancetype)shared;
@end

@implementation SCIYTTabButtonTarget

+ (instancetype)shared {
    static SCIYTTabButtonTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCIYTTabButtonTarget alloc] init]; });
    return shared;
}

- (void)tapped {
    SCILogV(@"tab: download centre");
    [SCIYTDownloadCenter present];
}

@end


static char kSCITabButtonAdded;

/// Whether this controller is the bar along the bottom.
///
/// By name, at runtime, and by more than one name: YouTube has called it a pivot bar for
/// years, but "tab bar" is what it is, and matching both costs nothing while depending on
/// one costs the feature.
static BOOL SCIIsTabBarController(UIViewController *controller) {
    NSString *name = NSStringFromClass([controller class]);
    if (![name hasPrefix:@"YT"]) return NO;

    return [name containsString:@"PivotBar"] || [name containsString:@"TabBar"];
}

static void SCIAddTabButton(UIViewController *controller) {
    if (!controller.view || objc_getAssociatedObject(controller, &kSCITabButtonAdded)) return;
    objc_setAssociatedObject(controller, &kSCITabButtonAdded, @YES, OBJC_ASSOCIATION_RETAIN);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    UIImageConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:22
                                                        weight:UIImageSymbolWeightRegular];
    [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"
                           withConfiguration:weight]
             forState:UIControlStateNormal];

    button.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    [button addTarget:[SCIYTTabButtonTarget shared]
               action:@selector(tapped)
     forControlEvents:UIControlEventTouchUpInside];

    [controller.view addSubview:button];

    // Both constraints relate the button to its own superview and to nothing else.
    //
    // Sibling constraints are what took the settings panel down twice, in CoreAutoLayout,
    // where the error names an anchor and not a file. A child pinned to its parent has no
    // second view to be inconsistent with.
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-6],
        [button.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [button.widthAnchor constraintEqualToConstant:38],
        [button.heightAnchor constraintEqualToConstant:38]
    ]];

    SCILogV(@"tab: button added to %@", NSStringFromClass([controller class]));
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!SCIPrefEnabled(SCIPrefTabButton)) return;
    if (!SCIIsTabBarController(self)) return;

    SCIAddTabButton(self);
}

%end
