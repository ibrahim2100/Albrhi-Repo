#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"
#import "../../../modules/JGProgressHUD/JGProgressHUD.h"

///
/// Copy any text. IGCoreTextView is Instagram's shared rich-text view — captions,
/// comments and bios all render through it — so one hook covers them all. Long-press
/// copies the full text as written.
///

%hook IGCoreTextView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"copy_description"]) {
        [self addHandleLongPress];
    }

    return;
}
%new - (void)addHandleLongPress {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self addGestureRecognizer:longPress];
}

%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSString *result = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!result.length) return;

    [UIPasteboard generalPasteboard].string = result;

    JGProgressHUD *HUD = [[JGProgressHUD alloc] init];
    HUD.textLabel.text = SCILocalized(@"p_copied_text");
    HUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];

    [HUD showInView:topMostController().view];
    [HUD dismissAfterDelay:2.0];
}
%end