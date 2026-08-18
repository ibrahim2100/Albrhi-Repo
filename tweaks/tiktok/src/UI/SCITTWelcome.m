#import "SCITTWelcome.h"
#import "../Tweak.h"
#import "../Prefs.h"
#import "../Localization/SCILocalize.h"

///
/// Built from the same material as everything else this tweak draws: a dark blurred card with a
/// hairline edge, the accent disc, the same corner curve. The saving banner, the feed button, the
/// confirmation sheet and this screen are one family, which is the whole reason the tweak looks
/// deliberate rather than assembled.
///
/// **A view in the key window rather than a presented view controller**, for the reason
/// `SCITTSheet` documents: TikTok often has something presented already, and presenting onto a
/// controller mid-transition either fails silently or throws. Here it matters more than usual --
/// this runs seconds after launch, which is exactly when TikTok is putting its own things up.
///

/// The one welcome on screen, if any.
static UIView *sciWelcomeOverlay = nil;

@implementation SCITTWelcome

+ (UIWindow *)window {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) return candidate;
        }
    }
    return nil;
}

+ (void)showIfNeeded {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults stringForKey:SCIPrefWelcomeSeen].length) return;

    // Recorded before it is drawn, not after it is dismissed. A launch where the screen is put up
    // and the app is killed a second later would otherwise show it again next time, forever, on a
    // device that keeps doing that -- and the failure mode of recording early is one missed
    // welcome, while the failure mode of recording late is an unkillable one.
    [defaults setObject:SCIVersionString forKey:SCIPrefWelcomeSeen];

    [self show];
}

+ (void)dismiss {
    UIView *overlay = sciWelcomeOverlay;
    if (!overlay) return;
    sciWelcomeOverlay = nil;

    UIView *card = [overlay viewWithTag:1];
    [UIView animateWithDuration:0.24 animations:^{
        overlay.alpha = 0;
        card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

+ (void)startTapped {
    [self dismiss];
}

/// One feature: a coloured disc, a title, and a line saying what it means.
+ (UIView *)rowWithSymbol:(NSString *)symbol
                    color:(UIColor *)color
                    title:(NSString *)title
                     note:(NSString *)note {
    UIView *disc = [[UIView alloc] init];
    disc.backgroundColor = [color colorWithAlphaComponent:0.22];
    disc.layer.cornerRadius = 11;
    disc.layer.cornerCurve = kCACornerCurveContinuous;
    disc.translatesAutoresizingMaskIntoConstraints = NO;
    [disc.widthAnchor constraintEqualToConstant:36].active = YES;
    [disc.heightAnchor constraintEqualToConstant:36].active = YES;

    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:symbol
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16
                                                                                 weight:UIImageSymbolWeightSemibold]]];
    glyph.tintColor = color;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    [disc addSubview:glyph];
    [glyph.centerXAnchor constraintEqualToAnchor:disc.centerXAnchor].active = YES;
    [glyph.centerYAnchor constraintEqualToAnchor:disc.centerYAnchor].active = YES;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.numberOfLines = 0;

    UILabel *noteLabel = [[UILabel alloc] init];
    noteLabel.text = note;
    noteLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    noteLabel.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    noteLabel.numberOfLines = 0;

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, noteLabel]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[disc, text]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    // Top, not centre: a two-line note would otherwise pull the disc down beside the second line.
    row.alignment = UIStackViewAlignmentTop;
    return row;
}

+ (void)show {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self show]; });
        return;
    }

    UIWindow *window = [self window];
    if (!window) return;

    [self dismiss];

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    overlay.alpha = 0;
    [window addSubview:overlay];

    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];
    card.tag = 1;
    card.layer.cornerRadius = 30;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:card];

    // The mark: the accent disc and the down arrow, the same pair the settings header and the feed
    // button use.
    UIView *mark = [[UIView alloc] init];
    mark.backgroundColor = SCIAccent();
    mark.layer.cornerRadius = 16;
    mark.layer.cornerCurve = kCACornerCurveContinuous;
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [mark.widthAnchor constraintEqualToConstant:56].active = YES;
    [mark.heightAnchor constraintEqualToConstant:56].active = YES;

    UIImageView *markGlyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26
                                                                                 weight:UIImageSymbolWeightBold]]];
    markGlyph.tintColor = [UIColor whiteColor];
    markGlyph.translatesAutoresizingMaskIntoConstraints = NO;
    [mark addSubview:markGlyph];
    [markGlyph.centerXAnchor constraintEqualToAnchor:mark.centerXAnchor].active = YES;
    [markGlyph.centerYAnchor constraintEqualToAnchor:mark.centerYAnchor].active = YES;

    UIStackView *markRow = [[UIStackView alloc] initWithArrangedSubviews:@[mark]];
    markRow.axis = UILayoutConstraintAxisVertical;
    markRow.alignment = UIStackViewAlignmentCenter;

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"welcome_title");
    title.font = [UIFont systemFontOfSize:23 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 0;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = [NSString stringWithFormat:SCILocalized(@"welcome_subtitle"), SCIVersionString];
    subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;

    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 16;
    [rows addArrangedSubview:[self rowWithSymbol:@"arrow.down"
                                           color:SCIAccent()
                                           title:SCILocalized(@"welcome_download")
                                            note:SCILocalized(@"welcome_download_note")]];
    [rows addArrangedSubview:[self rowWithSymbol:@"photo.stack"
                                           color:[UIColor systemPinkColor]
                                           title:SCILocalized(@"welcome_photos")
                                            note:SCILocalized(@"welcome_photos_note")]];
    [rows addArrangedSubview:[self rowWithSymbol:@"nosign"
                                           color:[UIColor systemRedColor]
                                           title:SCILocalized(@"welcome_clean")
                                            note:SCILocalized(@"welcome_clean_note")]];
    [rows addArrangedSubview:[self rowWithSymbol:@"hand.point.up.left.fill"
                                           color:[UIColor systemTealColor]
                                           title:SCILocalized(@"welcome_settings")
                                            note:SCILocalized(@"welcome_settings_note")]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[markRow, title, subtitle]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:16 afterView:markRow];
    [stack setCustomSpacing:22 afterView:subtitle];
    [stack addArrangedSubview:rows];
    [card.contentView addSubview:stack];

    // **The panel gate, said here or nowhere.** A fresh install of the suite patches nothing until
    // the app is switched on in Settings › Albrhi -- that is deliberate, since one install carries
    // four tweaks -- and somebody meeting this screen for the first time is exactly the person who
    // would otherwise conclude the tweak is broken. Shown only when it is actually off.
    if (!SCIPanelAllowsThisApp()) {
        UILabel *gate = [[UILabel alloc] init];
        gate.text = SCILocalized(@"gate_off");
        gate.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        gate.textColor = [UIColor systemOrangeColor];
        gate.textAlignment = NSTextAlignmentCenter;
        gate.numberOfLines = 0;

        UIView *banner = [[UIView alloc] init];
        banner.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.14];
        banner.layer.cornerRadius = 12;
        banner.layer.cornerCurve = kCACornerCurveContinuous;
        gate.translatesAutoresizingMaskIntoConstraints = NO;
        [banner addSubview:gate];
        [NSLayoutConstraint activateConstraints:@[
            [gate.topAnchor constraintEqualToAnchor:banner.topAnchor constant:10],
            [gate.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-10],
            [gate.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:12],
            [gate.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-12],
        ]];

        [stack setCustomSpacing:20 afterView:rows];
        [stack addArrangedSubview:banner];
    }

    UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem];
    start.backgroundColor = SCIAccent();
    start.layer.cornerRadius = 15;
    start.layer.cornerCurve = kCACornerCurveContinuous;
    start.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [start setTitle:SCILocalized(@"welcome_start") forState:UIControlStateNormal];
    [start setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [start addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [start.heightAnchor constraintEqualToConstant:54].active = YES;

    [stack setCustomSpacing:24 afterView:stack.arrangedSubviews.lastObject];
    [stack addArrangedSubview:start];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor],
        [card.widthAnchor constraintLessThanOrEqualToConstant:360],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:overlay.leadingAnchor constant:20],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:overlay.trailingAnchor constant:-20],
        // Never taller than the screen it is drawn on: the card grows with its text, and a long
        // translation on a small phone would otherwise run off both ends with no way to reach the
        // button.
        [card.topAnchor constraintGreaterThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.topAnchor constant:12],
        [card.bottomAnchor constraintLessThanOrEqualToAnchor:overlay.safeAreaLayoutGuide.bottomAnchor constant:-12],

        [stack.topAnchor constraintEqualToAnchor:card.contentView.topAnchor constant:26],
        [stack.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor constant:-20],
    ]];

    NSLayoutConstraint *wide = [card.widthAnchor constraintEqualToConstant:360];
    wide.priority = UILayoutPriorityDefaultHigh;
    wide.active = YES;

    sciWelcomeOverlay = overlay;

    card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.42
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        overlay.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
