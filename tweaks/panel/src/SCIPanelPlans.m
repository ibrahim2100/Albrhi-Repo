#import "SCIPanelPlans.h"
#import "Localization/SCILocalize.h"
#import "shared/src/SCILicense.h"

///
/// Where a buyer reaches Albrhi.
///
/// Empty until a number is set, and the button is *not drawn* when it is empty rather than drawn
/// and dead: a contact button that opens nothing is worse than no contact button, because the
/// person has already decided to pay by the time they press it.
///
/// International format, digits only — `wa.me` rejects anything else, including the leading `+`.
static NSString *const kSCIWhatsApp = @"966593010901";

/// One row of the card.
typedef struct {
    __unsafe_unretained NSString *titleKey;
    __unsafe_unretained NSString *noteKey;
    NSInteger days;          ///< 0 with `lifetime` set means no end date
    BOOL lifetime;
    BOOL trial;
} SCIPlan;

static const SCIPlan kSCIPlans[] = {
    { @"plan_trial",    @"plan_trial_note",    7,    NO,  YES },
    { @"plan_month",    @"plan_month_note",    30,   NO,  NO  },
    { @"plan_halfyear", @"plan_halfyear_note", 180,  NO,  NO  },
    { @"plan_year",     @"plan_year_note",     365,  NO,  NO  },
    { @"plan_life",     @"plan_life_note",     0,    YES, NO  },
};

static const size_t kSCIPlanCount = sizeof(kSCIPlans) / sizeof(kSCIPlans[0]);


@interface SCIPanelPlansView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIStackView *rows;
@property (nonatomic, strong) UILabel *status;
@end


@implementation SCIPanelPlansView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.45];

    UITapGestureRecognizer *dismiss =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    dismiss.cancelsTouchesInView = NO;

    // The delegate is what makes the card immune to its own dismissal, and it was declared
    // without being set once already in this repository -- a delegate method nobody asks is
    // exactly as useful as no delegate method.
    dismiss.delegate = self;
    [self addGestureRecognizer:dismiss];

    [self buildCard];
    return self;
}

/// A tap on the card itself must not close it, and a recogniser on the dimmed background cannot
/// tell the difference on its own -- it receives every touch in the whole view, card included.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    return !CGRectContainsPoint(self.card.frame, [touch locationInView:self]);
}

- (void)buildCard {
    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.card.layer.cornerRadius = 22;
    self.card.layer.cornerCurve = kCACornerCurveContinuous;
    self.card.clipsToBounds = YES;
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.card];

    // A scroll view, because five plans plus a footer is taller than a landscape phone and this
    // is the one screen that must never be the reason somebody could not reach the buy button.
    UIScrollView *scroller = [[UIScrollView alloc] init];
    scroller.translatesAutoresizingMaskIntoConstraints = NO;
    scroller.showsVerticalScrollIndicator = NO;
    [self.card addSubview:scroller];

    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 14;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroller addSubview:content];

    [content addArrangedSubview:[self header]];

    self.rows = [[UIStackView alloc] init];
    self.rows.axis = UILayoutConstraintAxisVertical;
    self.rows.spacing = 10;
    [content addArrangedSubview:self.rows];
    [self buildRows];

    self.status = [[UILabel alloc] init];
    self.status.font = [UIFont systemFontOfSize:13];
    self.status.textColor = [UIColor secondaryLabelColor];
    self.status.numberOfLines = 0;
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.text = SCILocalized(@"plans_device_note");
    [content addArrangedSubview:self.status];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:SCILocalized(@"cancel") forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [content addArrangedSubview:close];

    [NSLayoutConstraint activateConstraints:@[
        [self.card.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.card.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.card.widthAnchor constraintLessThanOrEqualToConstant:420],
        [self.card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor
                                                             constant:16],
        [self.card.trailingAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor
                                                           constant:-16],
        [self.card.topAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.topAnchor
                                                         constant:20],
        [self.card.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor
                                                        constant:-20],

        [scroller.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:22],
        [scroller.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-20],
        [scroller.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:18],
        [scroller.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-18],

        [content.topAnchor constraintEqualToAnchor:scroller.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroller.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroller.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroller.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroller.widthAnchor],
    ]];

    // The card grows with its content and stops at the screen: a fixed height is wrong on every
    // phone but the one it was measured on.
    NSLayoutConstraint *width = [self.card.widthAnchor constraintEqualToConstant:420];
    width.priority = UILayoutPriorityDefaultHigh;
    width.active = YES;
}

- (UIView *)header {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.alignment = UIStackViewAlignmentCenter;

    UIImageView *mark = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill"]];
    mark.tintColor = [UIColor systemTealColor];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    [mark.heightAnchor constraintEqualToConstant:38].active = YES;
    [stack addArrangedSubview:mark];

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"plans_title");
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 0;
    [stack addArrangedSubview:title];

    UILabel *note = [[UILabel alloc] init];
    note.text = SCILocalized(@"plans_note");
    note.font = [UIFont systemFontOfSize:14];
    note.textColor = [UIColor secondaryLabelColor];
    note.textAlignment = NSTextAlignmentCenter;
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];

    return stack;
}

- (void)buildRows {
    for (UIView *old in self.rows.arrangedSubviews) [old removeFromSuperview];

    for (size_t i = 0; i < kSCIPlanCount; i++) {
        SCIPlan plan = kSCIPlans[i];

        // The free week is drawn only while it can still be taken. A row that exists to be
        // refused is a row that teaches somebody the screen is broken.
        if (plan.trial && SCILicenseAllows()) continue;

        // And the contact plans need somewhere to go. With no number set they would open nothing.
        if (!plan.trial && kSCIWhatsApp.length == 0) continue;

        [self.rows addArrangedSubview:[self rowForPlan:plan index:(NSInteger)i]];
    }

    if (self.rows.arrangedSubviews.count == 0) {
        UILabel *none = [[UILabel alloc] init];
        none.text = SCILocalized(@"plans_none");
        none.font = [UIFont systemFontOfSize:14];
        none.textColor = [UIColor secondaryLabelColor];
        none.textAlignment = NSTextAlignmentCenter;
        none.numberOfLines = 0;
        [self.rows addArrangedSubview:none];
    }
}

- (UIView *)rowForPlan:(SCIPlan)plan index:(NSInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = index;
    button.backgroundColor = plan.trial ? [UIColor systemTealColor]
                                        : [UIColor tertiarySystemBackgroundColor];
    button.layer.cornerRadius = 14;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    [button addTarget:self action:@selector(planTapped:)
     forControlEvents:UIControlEventTouchUpInside];

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(plan.titleKey);
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.textColor = plan.trial ? [UIColor whiteColor] : [UIColor labelColor];

    UILabel *note = [[UILabel alloc] init];
    note.text = SCILocalized(plan.noteKey);
    note.font = [UIFont systemFontOfSize:13];
    note.textColor = plan.trial ? [UIColor.whiteColor colorWithAlphaComponent:0.85]
                                : [UIColor secondaryLabelColor];
    note.numberOfLines = 0;

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, note]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.userInteractionEnabled = NO;      // the button underneath takes the tap
    [button addSubview:text];

    [NSLayoutConstraint activateConstraints:@[
        [text.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:16],
        [text.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-16],
        [text.topAnchor constraintEqualToAnchor:button.topAnchor constant:12],
        [text.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-12],
    ]];

    return button;
}

- (void)planTapped:(UIButton *)sender {
    SCIPlan plan = kSCIPlans[sender.tag];

    if (plan.trial) {
        sender.enabled = NO;
        self.status.text = SCILocalized(@"plans_working");

        __weak __typeof(self) weakSelf = self;
        SCILicenseStartTrial(^(SCILicenseServerResult result) {
            sender.enabled = YES;

            // Five outcomes, five sentences. "already used", "you already have a licence" and
            // "the network said nothing" are three different things to be told, and the last is
            // never a licence problem.
            switch (result) {
                case SCILicenseServerOK:
                    weakSelf.status.text = SCILocalized(@"plans_trial_ok");
                    [weakSelf buildRows];
                    if (weakSelf.onChange) weakSelf.onChange();
                    break;
                case SCILicenseServerTrialUsed:
                    weakSelf.status.text = SCILocalized(@"plans_trial_used");
                    break;
                case SCILicenseServerAlreadyLicensed:
                    weakSelf.status.text = SCILocalized(@"plans_trial_have");
                    break;
                case SCILicenseServerNotConfigured:
                    weakSelf.status.text = SCILocalized(@"plans_no_server");
                    break;
                default:
                    weakSelf.status.text = SCILocalized(@"plans_unreachable");
                    break;
            }
        });
        return;
    }

    [self openContactForPlan:plan];
}

///
/// Opens the message with everything already written in it.
///
/// The device code is the one thing a person cannot be asked to retype: sixteen hex characters,
/// copied from one screen into another, is where a sale is lost. So it goes in the message body,
/// and the clipboard gets it too — a share that fails silently must not take the code with it.
///
- (void)openContactForPlan:(SCIPlan)plan {
    NSString *body = [NSString stringWithFormat:SCILocalized(@"plans_message"),
                      SCILocalized(plan.titleKey), SCILicenseFingerprint()];

    [UIPasteboard generalPasteboard].string = body;

    NSString *encoded = [body stringByAddingPercentEncodingWithAllowedCharacters:
                            [NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
    NSURL *url = [NSURL URLWithString:
        [NSString stringWithFormat:@"https://wa.me/%@?text=%@", kSCIWhatsApp, encoded]];

    if (!url) { self.status.text = SCILocalized(@"plans_copied"); return; }

    // Settings may refuse to open a URL from a preference bundle on some builds, and the answer
    // to that is the clipboard above rather than a dead end.
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL ok) {
        if (!ok) self.status.text = SCILocalized(@"plans_copied");
    }];
}

- (void)close {
    [UIView animateWithDuration:0.2
                     animations:^{ self.alpha = 0; }
                     completion:^(BOOL finished) { [self removeFromSuperview]; }];
}

@end


@implementation SCIPanelPlans

+ (void)presentWithChange:(void (^)(void))onChange {
    UIWindow *key = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { key = window; break; }
    }
    if (!key) return;

    SCIPanelPlansView *view = [[SCIPanelPlansView alloc] initWithFrame:key.bounds];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.onChange = onChange;
    view.alpha = 0;

    [key addSubview:view];
    [UIView animateWithDuration:0.2 animations:^{ view.alpha = 1; }];
}

@end
