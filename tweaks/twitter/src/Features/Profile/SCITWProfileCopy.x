#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITWProfileCopy.h"
#import "Prefs.h"
#import "SCILog.h"
#import "Localization/SCILocalize.h"

// Declared because a %hook only gets a forward declaration, and this one reads `self.view`.
// Rule 3 in tools/check.py exists for exactly this, and three builds have gone to it.
@interface T1ProfileHeaderViewController : UIViewController
@end

static BOOL sciProfilePresent = NO;
static NSUInteger sciGesturesAdded = 0, sciCopied = 0;
static char kSCIProfileGestureAdded;

/// Every readable line the header is drawing, in the order it draws them.
///
/// Depth-first over the real view tree rather than a model lookup: what is on screen is
/// what somebody meant to copy. Empty and duplicate lines are dropped because a header
/// repeats the handle in more than one label on some layouts.
static NSArray<NSString *> *SCICollectLabels(UIView *root) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];

    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([view isKindOfClass:[UILabel class]]) {
            NSString *text = [(UILabel *)view text];
            text = [text stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (text.length && ![lines containsObject:text]) [lines addObject:text];
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return lines;
}


@interface SCITWProfileCopyHandler : NSObject
+ (instancetype)shared;
- (void)handle:(UILongPressGestureRecognizer *)gesture;
@end

@implementation SCITWProfileCopyHandler

+ (instancetype)shared {
    static SCITWProfileCopyHandler *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITWProfileCopyHandler alloc] init]; });
    return shared;
}

- (void)handle:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    NSArray<NSString *> *lines = SCICollectLabels(gesture.view);
    if (!lines.count) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"profile_copy_title")
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    // One action per line, plus everything at once. A single "copy the profile" action
    // would decide for somebody which of three things they wanted.
    for (NSString *line in lines) {
        NSString *title = line.length > 40 ? [[line substringToIndex:40]
                                              stringByAppendingString:@"…"] : line;
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [UIPasteboard generalPasteboard].string = line;
            sciCopied++;
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"profile_copy_all")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = [lines componentsJoinedByString:@"\n"];
        sciCopied++;
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIViewController *top = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { top = window.rootViewController; break; }
    }
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    sheet.popoverPresentationController.sourceView = gesture.view;
    sheet.popoverPresentationController.sourceRect = gesture.view.bounds;
    [top presentViewController:sheet animated:YES completion:nil];
}

@end


%group ProfileCopy

%hook T1ProfileHeaderViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefCopyProfileInfo]) return;

    UIView *view = self.view;
    if (!view || objc_getAssociatedObject(view, &kSCIProfileGestureAdded)) return;
    objc_setAssociatedObject(view, &kSCIProfileGestureAdded, @YES, OBJC_ASSOCIATION_RETAIN);

    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCITWProfileCopyHandler shared]
                                                      action:@selector(handle:)];

    // Does not cancel what it sits on: X's own taps inside the header keep working, and a
    // gesture that quietly disabled them would be a feature removing a feature.
    press.cancelsTouchesInView = NO;
    [view addGestureRecognizer:press];
    sciGesturesAdded++;
}

%end

%end


NSString *SCITWProfileCopyReport(void) {
    if (!sciProfilePresent) return @"profile copy: T1ProfileHeaderViewController not in this build";
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefCopyProfileInfo]) {
        return @"profile copy: off";
    }
    return [NSString stringWithFormat:@"profile copy: %lu header(s) armed, %lu copied",
            (unsigned long)sciGesturesAdded, (unsigned long)sciCopied];
}

void SCITWInstallProfileCopy(void) {
    sciProfilePresent = (NSClassFromString(@"T1ProfileHeaderViewController") != nil);
    if (!sciProfilePresent) {
        SCILogV(@"profile copy: T1ProfileHeaderViewController not in this build");
        return;
    }

    %init(ProfileCopy);
    SCILogV(@"profile copy attached");
}
