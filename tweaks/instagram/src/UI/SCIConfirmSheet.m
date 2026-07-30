#import "SCIConfirmSheet.h"
#import "../Utils.h"
#import "../InstagramHeaders.h"
#import "../Localization/SCILocalize.h"

@interface SCIConfirmSheetController : UIViewController
@property (nonatomic, copy, nullable) NSString *prompt;
@property (nonatomic, copy, nullable) NSString *symbolName;
@property (nonatomic, copy) void (^onConfirm)(void);
@property (nonatomic, copy, nullable) void (^onCancel)(void);
@property (nonatomic, strong) UIView *card;
@property (nonatomic, assign) BOOL answered;
@end

@implementation SCIConfirmSheetController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.45];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [self buildCard];
}

- (void)buildCard {
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;

    self.card = [[UIView alloc] init];
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    self.card.layer.cornerRadius = 26;
    self.card.layer.cornerCurve = kCACornerCurveContinuous;
    self.card.clipsToBounds = YES;
    [self.view addSubview:self.card];
    [self.card addSubview:blur];

    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.5];
    grabber.layer.cornerRadius = 2.5;
    [self.card addSubview:grabber];

    UIColor *accent = [SCIUtils SCIColor_Primary];

    // A tinted disc behind the glyph, so the sheet reads as one of Albrhi's rather
    // than as a system alert.
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [accent colorWithAlphaComponent:0.15];
    badge.layer.cornerRadius = 25;
    [self.card addSubview:badge];

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    UIImage *glyph = [UIImage systemImageNamed:(self.symbolName.length ? self.symbolName : @"questionmark")
                             withConfiguration:config];

    UIImageView *icon = [[UIImageView alloc] initWithImage:glyph];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = accent;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [badge addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = self.prompt.length ? self.prompt : SCILocalized(@"confirm_title");
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 0;
    [self.card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = SCILocalized(@"confirm_body");
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [self.card addSubview:subtitle];

    UIButton *confirm = [self buttonWithTitle:SCILocalized(@"confirm_yes")
                                   background:accent
                                    textColor:UIColor.whiteColor
                                       action:@selector(confirmTapped)];

    UIButton *cancel = [self buttonWithTitle:SCILocalized(@"confirm_no")
                                  background:[UIColor.systemGrayColor colorWithAlphaComponent:0.18]
                                   textColor:UIColor.labelColor
                                      action:@selector(cancelTapped)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, confirm]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 10;
    [self.card addSubview:buttons];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.card.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],

        [blur.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor],
        [blur.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor],
        [blur.topAnchor constraintEqualToAnchor:self.card.topAnchor],
        [blur.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor],

        [grabber.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
        [grabber.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:8],
        [grabber.widthAnchor constraintEqualToConstant:38],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [badge.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
        [badge.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:16],
        [badge.widthAnchor constraintEqualToConstant:50],
        [badge.heightAnchor constraintEqualToConstant:50],

        [icon.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],

        [title.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:14],
        [title.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-24],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [buttons.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20],
        [buttons.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [buttons.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        [buttons.heightAnchor constraintEqualToConstant:48],
        [buttons.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-18]
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title
                   background:(UIColor *)background
                    textColor:(UIColor *)textColor
                       action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = background;
    button.layer.cornerRadius = 15;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:textColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// The offset is set once the card has a height; before layout it has none and the
// animation would have nothing to travel.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    self.card.transform = CGAffineTransformMakeTranslation(0, self.card.bounds.size.height + 40);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Brisk on purpose. A confirmation is in the way of something the user has
    // already decided to do, so it should arrive rather than make an entrance; the
    // longer spring this had was noticeable every single time.
    [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.86
          initialSpringVelocity:0.6 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

// MARK: - Answers

- (void)confirmTapped {
    if (self.answered) return;
    self.answered = YES;

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    // Dismiss and act together rather than acting once the animation has finished.
    // Waiting meant the thing being confirmed did not start until the card had gone,
    // which is most of the delay felt between one confirmation and the next.
    void (^handler)(void) = self.onConfirm;
    [self dismissViewControllerAnimated:YES completion:nil];
    if (handler) handler();
}

- (void)cancelTapped {
    if (self.answered) return;
    self.answered = YES;

    void (^handler)(void) = self.onCancel;
    [self dismissViewControllerAnimated:YES completion:nil];
    if (handler) handler();
}

// Two recognisers in different views both fire, so the card is ruled out by where
// the touch landed rather than by adding one to it.
- (void)backgroundTapped:(UITapGestureRecognizer *)tap {
    if (CGRectContainsPoint(self.card.frame, [tap locationInView:self.view])) return;

    [self cancelTapped];
}

@end


@implementation SCIConfirmSheet

+ (void)presentWithTitle:(NSString *)title
                  symbol:(NSString *)symbol
                 confirm:(void (^)(void))confirm
                  cancel:(void (^)(void))cancel {

    SCIConfirmSheetController *sheet = [[SCIConfirmSheetController alloc] init];
    sheet.prompt = title;
    sheet.symbolName = symbol;
    sheet.onConfirm = confirm;
    sheet.onCancel = cancel;
    sheet.modalPresentationStyle = UIModalPresentationOverFullScreen;
    sheet.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [self present:sheet attempt:0];
}

/// Presents once the way is clear.
///
/// A confirmation often follows straight on from the previous one being dismissed,
/// and asking a controller that is still finishing a transition to present gets the
/// request dropped — which showed up as the second confirmation in a row taking a
/// noticeable moment to appear, or not appearing at all. Retrying on the next runloop
/// costs nothing and lets the transition finish first.
+ (void)present:(UIViewController *)sheet attempt:(NSInteger)attempt {
    UIViewController *host = topMostController();

    BOOL busy = host.isBeingDismissed || host.isBeingPresented || host.presentedViewController != nil;

    // Spaced out rather than retried on the next runloop: a dismissal takes about a
    // third of a second, and eight runloop turns pass in microseconds — they would
    // all be spent before the previous card had begun to leave. Eight attempts at
    // 50ms covers a dismissal with room to spare, and is bounded so a controller
    // that is somehow never ready cannot spin forever.
    if (busy && attempt < 8) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self present:sheet attempt:attempt + 1];
        });
        return;
    }

    [host presentViewController:sheet animated:YES completion:nil];
}

@end
