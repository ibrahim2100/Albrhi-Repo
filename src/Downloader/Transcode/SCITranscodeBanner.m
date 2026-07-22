#import "SCITranscodeBanner.h"
#import "../../Utils.h"

// A window that is invisible to touches except over its banner card, so the app
// underneath keeps receiving scrolls and taps while a transcode runs.
@interface SCIPassthroughWindow : UIWindow
@property (nonatomic, weak) UIView *card;
@end

@implementation SCIPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // Only the card (and its subviews) should swallow touches.
    UIView *v = hit;
    while (v) {
        if (v == self.card) return hit;
        v = v.superview;
    }
    return nil;
}
@end


@interface SCITranscodeBanner ()
@property (nonatomic, strong) SCIPassthroughWindow *window;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *resultIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UIView *track;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) NSLayoutConstraint *barWidth;
@property (nonatomic, assign) BOOL visible;
@end

@implementation SCITranscodeBanner

+ (instancetype)shared {
    static SCITranscodeBanner *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

// MARK: - Construction

- (UIWindowScene *)activeScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

- (void)build {
    UIWindowScene *scene = [self activeScene];
    if (!scene) return;

    self.window = [[SCIPassthroughWindow alloc] initWithWindowScene:scene];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = UIColor.clearColor;
    self.window.hidden = NO;

    UIView *host = self.window.rootViewController.view;

    // Frosted card.
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.layer.cornerRadius = 18;
    blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.clipsToBounds = YES;

    self.card = [[UIView alloc] init];
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    self.card.layer.cornerRadius = 18;
    self.card.layer.cornerCurve = kCACornerCurveContinuous;
    self.card.layer.shadowColor = UIColor.blackColor.CGColor;
    self.card.layer.shadowOpacity = 0.18;
    self.card.layer.shadowRadius = 16;
    self.card.layer.shadowOffset = CGSizeMake(0, 6);
    [host addSubview:self.card];
    [self.card addSubview:blur];

    self.window.card = self.card;

    // Leading indicator: spinner while working, checkmark/exclamation at the end.
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = [SCIUtils SCIColor_Primary];
    [self.spinner startAnimating];

    self.resultIcon = [[UIImageView alloc] init];
    self.resultIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.resultIcon.hidden = YES;

    self.titleLabel = [self labelWithSize:15 weight:UIFontWeightSemibold];
    self.detailLabel = [self labelWithSize:12 weight:UIFontWeightRegular];
    self.detailLabel.textColor = UIColor.secondaryLabelColor;

    // Centered, and shrink-to-fit rather than truncating to a leading "…" ellipsis
    // (which read as stray dots at the start, especially in RTL).
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.detailLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.5;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.detailLabel.adjustsFontSizeToFitWidth = YES;
    self.detailLabel.minimumScaleFactor = 0.5;
    self.detailLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.percentLabel = [self labelWithSize:15 weight:UIFontWeightBold];
    self.percentLabel.textColor = [SCIUtils SCIColor_Primary];
    self.percentLabel.textAlignment = NSTextAlignmentRight;
    [self.percentLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.detailLabel]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 1;
    text.translatesAutoresizingMaskIntoConstraints = NO;

    // Progress bar.
    self.track = [[UIView alloc] init];
    self.track.translatesAutoresizingMaskIntoConstraints = NO;
    self.track.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.25];
    self.track.layer.cornerRadius = 2;
    self.track.clipsToBounds = YES;

    self.bar = [[UIView alloc] init];
    self.bar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bar.backgroundColor = [SCIUtils SCIColor_Primary];
    [self.track addSubview:self.bar];

    for (UIView *v in @[self.spinner, self.resultIcon, text, self.percentLabel, self.track]) {
        [self.card addSubview:v];
    }

    self.barWidth = [self.bar.widthAnchor constraintEqualToConstant:0];

    UILayoutGuide *g = host.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.card.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:12],
        [self.card.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:-12],
        [self.card.topAnchor constraintEqualToAnchor:g.topAnchor constant:8],

        [blur.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor],
        [blur.topAnchor constraintEqualToAnchor:self.card.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor],

        [self.spinner.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:16],
        [self.spinner.centerYAnchor constraintEqualToAnchor:text.centerYAnchor],
        [self.resultIcon.centerXAnchor constraintEqualToAnchor:self.spinner.centerXAnchor],
        [self.resultIcon.centerYAnchor constraintEqualToAnchor:self.spinner.centerYAnchor],
        [self.resultIcon.widthAnchor constraintEqualToConstant:22],
        [self.resultIcon.heightAnchor constraintEqualToConstant:22],

        // The text fills the whole span between the spinner and the percent, and its
        // labels are centre-aligned within it — so it reads centred but never loses
        // width to a centreX tug-of-war (which was truncating the resolution).
        [text.leadingAnchor constraintEqualToAnchor:self.spinner.trailingAnchor constant:12],
        [text.trailingAnchor constraintEqualToAnchor:self.percentLabel.leadingAnchor constant:-8],
        [text.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:12],

        [self.percentLabel.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-16],
        [self.percentLabel.centerYAnchor constraintEqualToAnchor:text.centerYAnchor],

        [self.track.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:16],
        [self.track.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-16],
        [self.track.topAnchor constraintEqualToAnchor:text.bottomAnchor constant:10],
        [self.track.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-14],
        [self.track.heightAnchor constraintEqualToConstant:4],

        [self.bar.leadingAnchor constraintEqualToAnchor:self.track.leadingAnchor],
        [self.bar.topAnchor constraintEqualToAnchor:self.track.topAnchor],
        [self.bar.bottomAnchor constraintEqualToAnchor:self.track.bottomAnchor],
        self.barWidth
    ]];

    // Start just above the screen for the slide-in.
    [host layoutIfNeeded];
    self.card.transform = CGAffineTransformMakeTranslation(0, -140);
    self.card.alpha = 0;
}

- (UILabel *)labelWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *l = [[UILabel alloc] init];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.font = [UIFont systemFontOfSize:size weight:weight];
    l.textColor = UIColor.labelColor;
    return l;
}

// MARK: - Public

- (void)showWithTitle:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) [self build];
        if (!self.window) return;

        self.titleLabel.text = title;
        self.detailLabel.text = @"";
        self.percentLabel.text = @"";
        self.resultIcon.hidden = YES;
        self.spinner.hidden = NO;
        [self.spinner startAnimating];
        self.bar.backgroundColor = [SCIUtils SCIColor_Primary];

        if (self.visible) return;
        self.visible = YES;

        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.8
              initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.card.transform = CGAffineTransformIdentity;
            self.card.alpha = 1;
        } completion:nil];
    });
}

- (void)setDetail:(NSString *)detail fraction:(float)fraction {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        self.detailLabel.text = detail;

        if (fraction < 0) {
            self.percentLabel.text = @"";
            [self pulse];
            return;
        }

        // A captured block parameter is const; clamp into a local instead.
        float f = MAX(0.0f, MIN(1.0f, fraction));
        self.percentLabel.text = [NSString stringWithFormat:@"%.0f%%", f * 100];

        CGFloat full = self.track.bounds.size.width;
        self.barWidth.constant = full * f;
        [UIView animateWithDuration:0.25 animations:^{ [self.card layoutIfNeeded]; }];
    });
}

- (void)pulse {
    [UIView animateWithDuration:0.6 delay:0
                        options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                     animations:^{ self.bar.alpha = 0.35; }
                     completion:nil];
    self.barWidth.constant = self.track.bounds.size.width * 0.4;
    [self.card layoutIfNeeded];
}

- (void)finishWithSuccess:(BOOL)success message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;

        [self.bar.layer removeAllAnimations];
        self.bar.alpha = 1;

        self.spinner.hidden = YES;
        [self.spinner stopAnimating];

        UIColor *tint = success ? UIColor.systemGreenColor : UIColor.systemOrangeColor;
        NSString *symbol = success ? @"checkmark.circle.fill" : @"exclamationmark.triangle.fill";
        self.resultIcon.image = [UIImage systemImageNamed:symbol];
        self.resultIcon.tintColor = tint;
        self.resultIcon.hidden = NO;

        self.titleLabel.text = message;
        self.detailLabel.text = @"";
        self.percentLabel.text = @"";

        self.bar.backgroundColor = tint;
        self.barWidth.constant = self.track.bounds.size.width;
        [UIView animateWithDuration:0.25 animations:^{ [self.card layoutIfNeeded]; }];

        [self dismissAfter:success ? 1.4 : 2.2];
    });
}

- (void)dismissAfter:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.35 animations:^{
            self.card.transform = CGAffineTransformMakeTranslation(0, -140);
            self.card.alpha = 0;
        } completion:^(BOOL finished) {
            self.window.hidden = YES;
            self.window = nil;
            self.card = nil;
            self.visible = NO;
        }];
    });
}

@end
