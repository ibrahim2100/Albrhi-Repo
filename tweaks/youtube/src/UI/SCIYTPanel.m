#import "SCIYTPanel.h"
#import "../Tweak.h"
#import "../SCILog.h"
#import "../Localization/SCILocalize.h"
#import "../Diagnostics/SCIYTDiagnostics.h"

/// YouTube's red, so the panel belongs to the app it is sitting over rather than
/// looking like a foreign screen. Written out rather than read from
/// YTCommonColorPalette: one accent colour is not worth a dependency on a class whose
/// shape has not been verified, and this whole version exists because of a dependency
/// that was not verified.
static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

@interface SCIYTPanelController : UIViewController
@property (nonatomic, strong) UIView *card;
@end

@implementation SCIYTPanelController

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
    UIColor *accent = SCIAccent();

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];
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

    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [accent colorWithAlphaComponent:0.18];
    badge.layer.cornerRadius = 22;
    [self.card addSubview:badge];

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"play.rectangle.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19
                                                                                 weight:UIImageSymbolWeightSemibold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = accent;
    [badge addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = SCILocalized(@"panel_title");
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    [self.card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = [NSString stringWithFormat:@"%@ · %@",
        SCILocalized(@"panel_subtitle"), SCIVersionString];
    subtitle.font = [UIFont systemFontOfSize:12.5];
    subtitle.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.6];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [self.card addSubview:subtitle];

    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 8;
    [rows addArrangedSubview:[self loggingRow]];
    [rows addArrangedSubview:[self diagnosticsRow]];
    [self.card addSubview:rows];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    close.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.14];
    close.layer.cornerRadius = 15;
    close.layer.cornerCurve = kCACornerCurveContinuous;
    close.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [close setTitle:SCILocalized(@"panel_close") forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:close];

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
        [badge.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:14],
        [badge.widthAnchor constraintEqualToConstant:44],
        [badge.heightAnchor constraintEqualToConstant:44],
        [icon.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],

        [title.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-20],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [rows.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18],
        [rows.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [rows.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],

        [close.topAnchor constraintEqualToAnchor:rows.bottomAnchor constant:14],
        [close.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [close.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        [close.heightAnchor constraintEqualToConstant:48],
        [close.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-18],
    ]];
}

- (UIView *)rowContainer {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.08];
    row.layer.cornerRadius = 16;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:58].active = YES;
    return row;
}

- (UILabel *)rowLabel:(NSString *)text detail:(NSString *)detail {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;

    NSMutableAttributedString *body = [[NSMutableAttributedString alloc]
        initWithString:text attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: UIColor.whiteColor,
        }];

    if (detail.length) {
        [body appendAttributedString:[[NSAttributedString alloc]
            initWithString:[@"\n" stringByAppendingString:detail] attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:11.5],
                NSForegroundColorAttributeName: [UIColor.whiteColor colorWithAlphaComponent:0.55],
            }]];
    }

    label.attributedText = body;
    return label;
}

- (UIView *)loggingRow {
    UIView *row = [self rowContainer];

    UILabel *label = [self rowLabel:SCILocalized(@"verbose_logging")
                             detail:SCILocalized(@"verbose_logging_note")];
    [row addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = SCIAccent();
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"verbose_logging"];
    [toggle addTarget:self action:@selector(loggingToggled:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [label.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-12],
        [label.topAnchor constraintEqualToAnchor:row.topAnchor constant:11],
        [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-11],

        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];

    return row;
}

- (UIView *)diagnosticsRow {
    UIView *row = [self rowContainer];

    UILabel *label = [self rowLabel:SCILocalized(@"diagnostics")
                             detail:SCILocalized(@"diagnostics_note")];
    [row addSubview:label];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = [UIColor.whiteColor colorWithAlphaComponent:0.4];
    [row addSubview:chevron];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(diagnosticsTapped)];
    [row addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [label.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-12],
        [label.topAnchor constraintEqualToAnchor:row.topAnchor constant:11],
        [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-11],

        [chevron.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];

    return row;
}

// MARK: - Actions

- (void)loggingToggled:(UISwitch *)toggle {
    [[NSUserDefaults standardUserDefaults] setBool:toggle.isOn forKey:@"verbose_logging"];
}

- (void)diagnosticsTapped {
    UIViewController *page = [SCIYTDiagnostics viewController];

    // Wrapped in a navigation controller of our own: this panel is presented, not
    // pushed, so there is no navigation stack here to push onto -- and reaching for
    // YouTube's would mean depending on its hierarchy again.
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;

    page.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:SCILocalized(@"panel_close")
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(dismissPage)];

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissPage {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)recognizer {
    // Only a tap outside the card dismisses; a tap on a row must not.
    CGPoint point = [recognizer locationInView:self.view];
    if (CGRectContainsPoint(self.card.frame, point)) return;

    [self closeTapped];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end


@implementation SCIYTPanel

+ (UIViewController *)topMostController {
    UIWindow *key = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                key = window;
                break;
            }
        }
        if (key) break;
    }

    UIViewController *controller = key.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

+ (void)present {
    UIViewController *host = [self topMostController];
    if (!host) {
        SCILogV(@"panel: no controller to present from");
        return;
    }

    // Declined rather than attempted while something is mid-transition. Presenting
    // onto a controller that is itself appearing or disappearing is how a panel ends
    // up invisible but blocking every touch underneath it.
    if (host.isBeingPresented || host.isBeingDismissed) {
        SCILogV(@"panel: host is mid-transition, not presenting");
        return;
    }

    SCIYTPanelController *panel = [[SCIYTPanelController alloc] init];
    panel.modalPresentationStyle = UIModalPresentationOverFullScreen;
    panel.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [host presentViewController:panel animated:YES completion:nil];
}

@end
