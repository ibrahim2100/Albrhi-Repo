#import "SCIPanelPlans.h"
#import "Localization/SCILocalize.h"
#import "shared/src/SCILicense.h"
#import "shared/src/SCIPanelGate.h"

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

    //
    // **A scroll view has no height of its own, and this is what made the card small and empty.**
    //
    // Pinning the content to the scroller's edges sets its *contentSize* — it says nothing about
    // how tall the scroller should be. So nothing in the whole chain gave the card a height: it
    // collapsed to whatever the solver picked, and `clipsToBounds` hid the five rows inside it.
    // Every row was built, every label had its text; none of it had anywhere to be drawn.
    //
    // The height is asked for at less than required priority so it yields to the two constraints
    // that keep the card on the screen — top and bottom against the safe area. On a tall phone
    // the card is exactly as tall as its content; on a short one it stops at the screen and the
    // content scrolls, which is the whole reason there is a scroll view here at all.
    //
    NSLayoutConstraint *height = [scroller.heightAnchor constraintEqualToAnchor:content.heightAnchor];
    height.priority = UILayoutPriorityDefaultHigh;
    height.active = YES;

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

        // **The free week stays on the card even when it cannot be taken, greyed and explained.**
        //
        // It used to be hidden, on the reasoning that a row which can only be refused teaches
        // somebody the screen is broken. The opposite happened: a person with a licence looked
        // for the free week, found no row at all, and concluded the button was broken. An absence
        // answers nothing — "why is there no trial here" is a real question and the row is the
        // only place to answer it.
        BOOL unavailable = plan.trial && SCILicenseAllows();

        // And the contact plans need somewhere to go. With no number set they would open nothing.
        if (!plan.trial && kSCIWhatsApp.length == 0) continue;

        [self.rows addArrangedSubview:[self rowForPlan:plan
                                                 index:(NSInteger)i
                                           unavailable:unavailable]];
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

- (UIView *)rowForPlan:(SCIPlan)plan index:(NSInteger)index unavailable:(BOOL)unavailable {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = index;
    button.enabled = !unavailable;
    button.alpha = unavailable ? 0.5 : 1.0;
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
    note.text = unavailable ? SCILocalized(@"plans_trial_have") : SCILocalized(plan.noteKey);
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
///
/// Name, then number, then the request, then WhatsApp — in that order and for that reason.
///
/// **The request is filed before the message is opened.** If it were the other way round, closing
/// WhatsApp or never sending the message would leave nothing behind: the panel would show no
/// request, and the only record of somebody wanting to buy something would be a draft on their
/// phone. Sending it first means a request that reaches the panel even if the conversation never
/// happens — which is the case worth catching, because that person meant to pay.
///
- (void)openContactForPlan:(SCIPlan)plan {
    UIAlertController *form =
        [UIAlertController alertControllerWithTitle:SCILocalized(plan.titleKey)
                                            message:SCILocalized(@"plans_who_note")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [form addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = SCILocalized(@"plans_who_name");
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
        field.text = SCIPanelReadString(@"licence_buyer_name", nil) ?: @"";
    }];
    [form addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = SCILocalized(@"plans_who_phone");
        field.keyboardType = UIKeyboardTypePhonePad;
        field.text = SCIPanelReadString(@"licence_buyer_phone", nil) ?: @"";
    }];

    __weak __typeof(self) weakSelf = self;
    [form addAction:[UIAlertAction actionWithTitle:SCILocalized(@"plans_send")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        NSCharacterSet *blank = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *name  = [form.textFields.firstObject.text stringByTrimmingCharactersInSet:blank];
        NSString *phone = [form.textFields.lastObject.text stringByTrimmingCharactersInSet:blank];

        if (!name.length || !phone.length) {
            weakSelf.status.text = SCILocalized(@"plans_who_missing");
            return;
        }

        // Remembered, so a second purchase does not ask again. Written to the panel's own domain,
        // which is the one this process may write and every part of Albrhi already reads.
        CFStringRef domain = (__bridge CFStringRef)@"com.albrhi.panel";
        CFPreferencesSetAppValue(CFSTR("licence_buyer_name"), (__bridge CFStringRef)name, domain);
        CFPreferencesSetAppValue(CFSTR("licence_buyer_phone"), (__bridge CFStringRef)phone, domain);
        CFPreferencesAppSynchronize(domain);

        weakSelf.status.text = SCILocalized(@"plans_working");

        SCILicenseRequestFromServer(plan.days, plan.lifetime, name, phone,
                                    SCILocalized(plan.titleKey),
                                    ^(SCILicenseServerResult result) {
            // The message opens either way. A request that did not reach the server is a reason
            // to talk to somebody, not a reason to stop them talking to you -- and the plan and
            // the device code are in the message regardless.
            weakSelf.status.text = (result == SCILicenseServerPending)
                ? SCILocalized(@"plans_sent")
                : SCILocalized(@"plans_sent_offline");

            [weakSelf openWhatsAppForPlan:plan name:name phone:phone];
            if (weakSelf.onChange) weakSelf.onChange();
        });
    }]];

    [form addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    UIViewController *host = self.window.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    [host presentViewController:form animated:YES completion:nil];
}

- (void)openWhatsAppForPlan:(SCIPlan)plan name:(NSString *)name phone:(NSString *)phone {
    NSString *body = [NSString stringWithFormat:SCILocalized(@"plans_message"),
                      SCILocalized(plan.titleKey), name, phone, SCILicenseFingerprint()];

    // The clipboard as well as the link. A share that fails silently must not take the device
    // code with it -- that string is the one thing nobody can be asked to reproduce.
    [UIPasteboard generalPasteboard].string = body;

    NSString *encoded = [body stringByAddingPercentEncodingWithAllowedCharacters:
                            [NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
    NSURL *url = [NSURL URLWithString:
        [NSString stringWithFormat:@"https://wa.me/%@?text=%@", kSCIWhatsApp, encoded]];

    if (!url) { self.status.text = SCILocalized(@"plans_copied"); return; }

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

+ (void)presentFrom:(UIViewController *)host change:(void (^)(void))onChange {
    //
    // Four places to draw, in order of how well each one works — and every one of them pinned
    // with constraints rather than a frame, which is the half the first fallback got wrong.
    //
    //   1. the controller's window        — covers the screen, above the navigation bar
    //   2. any window the scenes offer    — `keyWindow` is deprecated and unreliable in a
    //                                       preference bundle, so this does not ask for the flag
    //   3. the navigation controller       — still covers the whole page
    //   4. the controller's own view       — a PSListController's view *is* its table, so an
    //                                       overlay here lives in scrolling content: the worst
    //                                       of the four and still enormously better than nothing
    //
    UIView *canvas = host.view.window;

    if (!canvas) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (!window.hidden && window.bounds.size.width > 0) { canvas = window; break; }
            }
            if (canvas) break;
        }
    }

    if (!canvas) canvas = host.navigationController.view;
    if (!canvas) canvas = host.view;

    if (!canvas) {
        // Nothing left to draw on. Said out loud: this button exists to take somebody's money,
        // and a silent failure here is the most expensive silence in the package.
        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:SCILocalized(@"plans_title")
                                                message:SCILocalized(@"plans_cannot_show")
                                         preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok_button")
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [host presentViewController:alert animated:YES completion:nil];
        return;
    }

    SCIPanelPlansView *view = [[SCIPanelPlansView alloc] initWithFrame:canvas.bounds];
    view.onChange = onChange;
    view.alpha = 0;

    // Constraints, not an autoresizing mask.
    //
    // The mask resizes against a *superview's* bounds, and canvas #4 is a scroll view whose
    // bounds move as it scrolls -- so the overlay would drift off the top the moment somebody
    // touched the list. Pinned to the edges it stays put on all four canvases.
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [canvas addSubview:view];
    [canvas bringSubviewToFront:view];

    [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:canvas.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:canvas.trailingAnchor],
        [view.topAnchor constraintEqualToAnchor:canvas.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:canvas.bottomAnchor],
        [view.widthAnchor constraintEqualToAnchor:canvas.widthAnchor],
        [view.heightAnchor constraintEqualToAnchor:canvas.heightAnchor],
    ]];

    [UIView animateWithDuration:0.2 animations:^{ view.alpha = 1; }];
}

@end
