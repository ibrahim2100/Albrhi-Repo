#import "SCILKWelcome.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"

/// Which version last said hello. A string rather than a flag, so a later release can show
/// this again for something worth mentioning without anyone having to invent a second key.
///
/// Renamed once, deliberately, from "welcome_shown_version": the first version of -present
/// marked this *before* checking whether presenting would actually succeed, so a launch
/// where Locket's own UI had something on screen in the first 2.5 seconds -- its own splash,
/// a permission prompt, its own onboarding -- set the flag and then bailed at the "not over
/// another sheet" guard below, permanently, with nothing ever having appeared. A new key
/// gives every install one more real attempt under the corrected logic; the old key is
/// simply never read again.
static NSString *const kSCIWelcomeShown = @"welcome_shown_v2";


@implementation SCILKWelcome

+ (void)showIfFirstRun {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults stringForKey:kSCIWelcomeShown] length]) return;

    [self attempt:0];
}

/// Tried every 2.5 seconds, up to roughly a minute, rather than once.
///
/// A single attempt assumed Locket's own UI settles within one short window after
/// launch, and a real report said otherwise: nothing appeared at all. Locket's own
/// splash, permission prompts or onboarding can plausibly still be on screen well past
/// 2.5 seconds, and a one-shot attempt that finds them there gives up for the rest of
/// the app's life rather than for the rest of that one moment. Capped so a greeting
/// does not keep trying to interrupt someone using the app normally an hour in.
+ (void)attempt:(NSInteger)count {
    if (count >= 24) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Checked again -- a later attempt after an earlier one already succeeded is
        // the one case this loop must not repeat.
        if ([[[NSUserDefaults standardUserDefaults] stringForKey:kSCIWelcomeShown] length]) return;

        @try {
            if (![self present]) [self attempt:count + 1];
        } @catch (NSException *exception) {
            SCILogV(@"welcome: could not show — %@", exception.reason);
        }
    });
}

/// Returns whether it actually presented, so the retry loop above knows whether to try
/// again rather than assume one attempt was always going to be enough.
+ (BOOL)present {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) return NO;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;

    // Not over another sheet. Someone who opened something is doing something; a
    // greeting can wait -- and it now actually does wait rather than giving up, since
    // the caller retries whenever this returns NO.
    if (!top || top != window.rootViewController) return NO;

    // Marked here, immediately before showing, rather than back in +showIfFirstRun. The
    // exception guard around -present still means a crash inside init costs one attempt
    // and not every attempt forever; an attempt that merely finds something already on
    // screen costs nothing at all now -- it is not even counted as having tried.
    [[NSUserDefaults standardUserDefaults] setObject:SCIVersionString forKey:kSCIWelcomeShown];

    [top presentViewController:[[SCILKWelcome alloc] init] animated:YES completion:nil];
    return YES;
}

- (instancetype)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];

    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:56 weight:UIImageSymbolWeightSemibold];
    UIImageView *mark = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"lock.shield.fill" withConfiguration:weight]];
    mark.tintColor = SCIAccent();
    mark.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"welcome_title");
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 2;

    UILabel *version = [[UILabel alloc] init];
    version.text = SCIVersionString;
    version.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    version.textColor = SCIAccent();
    version.textAlignment = NSTextAlignmentCenter;

    UILabel *body = [[UILabel alloc] init];
    body.text = SCILocalized(@"welcome_body");
    body.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    body.textColor = [UIColor colorWithWhite:1 alpha:0.72];
    body.textAlignment = NSTextAlignmentCenter;
    body.numberOfLines = 0;

    UILabel *gesture = [[UILabel alloc] init];
    gesture.text = SCILocalized(@"welcome_gesture");
    gesture.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    gesture.textColor = SCIAccent();
    gesture.textAlignment = NSTextAlignmentCenter;
    gesture.numberOfLines = 0;

    UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
    [go setTitle:SCILocalized(@"welcome_go") forState:UIControlStateNormal];
    [go setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    go.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    go.backgroundColor = SCIAccent();
    go.layer.cornerRadius = 14;
    go.layer.cornerCurve = kCACornerCurveContinuous;
    [go addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [go.heightAnchor constraintEqualToConstant:52].active = YES;

    // One stack, pinned to its own margins and to nothing else. The settings panel this
    // project rebuilt three times died in CoreAutoLayout both times it was written as
    // siblings pinned to each other.
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
        @[mark, title, version, body, gesture]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 12;
    [stack setCustomSpacing:20 afterView:mark];
    [stack setCustomSpacing:24 afterView:version];
    [stack setCustomSpacing:22 afterView:body];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    go.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:go];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],

        [mark.heightAnchor constraintEqualToConstant:64],
        [mark.widthAnchor constraintEqualToConstant:64],

        [go.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [go.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        [go.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                        constant:-24]
    ]];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
