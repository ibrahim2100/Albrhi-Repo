#import "SCIWhatsNewViewController.h"
#import "SCIWhatsNew.h"
#import "../Utils.h"
#import "../Localization/SCILocalize.h"
#import "../Tweak.h"

@interface SCIWhatsNewViewController ()

@property (nonatomic) BOOL firstInstall;
@property (nonatomic) BOOL isIntro;   // the "how to open settings" welcome page
@property (nonatomic, strong) NSArray<UIView *> *animatedRows;

@end

@implementation SCIWhatsNewViewController

+ (void)presentIfNeededFromWindow:(UIWindow *)window {
    if (![SCIWhatsNew shouldPresent]) return;

    // First install: the intro ("how to open the settings") leads into what's new.
    // An update: straight to what's new.
    [self presentIntro:[SCIWhatsNew isFirstInstall] fromWindow:window];
}

+ (void)presentFromWindow:(UIWindow *)window {
    // The "show welcome screen again" button starts from the intro.
    [self presentIntro:YES fromWindow:window];
}

+ (void)presentIntro:(BOOL)intro fromWindow:(UIWindow *)window {
    UIViewController *presenter = [window rootViewController] ?: topMostController();
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }

    // Nothing to present from yet — the app is still building its UI. Bail rather
    // than half-presenting; the next launch will catch it.
    if (!presenter) return;

    SCIWhatsNewViewController *sheet = [[SCIWhatsNewViewController alloc] init];
    sheet.isIntro = intro;
    sheet.modalPresentationStyle = UIModalPresentationPageSheet;

    // Not dismissible by swipe: the button marks the version as seen, and a
    // swipe-away would show the same screen again next launch.
    sheet.modalInPresentation = YES;

    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.firstInstall = [SCIWhatsNew isFirstInstall];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    if ([SCILocalize isRTL]) {
        self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }

    [self buildContent];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self playEntranceAnimation];
}

// MARK: - Layout

- (void)buildContent {
    UIColor *accent = [SCIUtils SCIColor_Primary];

    // --- Hero ---
    UIImageView *hero = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"sparkles"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:46.0
                                                                                  weight:UIImageSymbolWeightSemibold]]];
    hero.tintColor = accent;
    hero.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *headline = [[UILabel alloc] init];
    headline.text = self.isIntro ? [SCIWhatsNew introHeadline]
                                  : [SCIWhatsNew headlineForFirstInstall:self.firstInstall];
    headline.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
    headline.textAlignment = NSTextAlignmentCenter;
    headline.numberOfLines = 0;
    headline.adjustsFontSizeToFitWidth = YES;
    headline.minimumScaleFactor = 0.7;

    UILabel *subheadline = [[UILabel alloc] init];
    subheadline.text = self.isIntro ? [SCIWhatsNew introSubheadline]
                                     : [SCIWhatsNew subheadlineForFirstInstall:self.firstInstall];
    subheadline.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    subheadline.textColor = [UIColor secondaryLabelColor];
    subheadline.textAlignment = NSTextAlignmentCenter;
    subheadline.numberOfLines = 0;

    // Beta pill: sets expectations up front, quietly. A tester who knows a build is
    // provisional reports problems instead of assuming the tweak is junk.
    UILabel *betaLabel = [[UILabel alloc] init];
    betaLabel.text = [NSString stringWithFormat:@"  %@  ", SCILocalized(@"wn_beta_badge")];
    betaLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    betaLabel.textColor = accent;
    betaLabel.backgroundColor = [accent colorWithAlphaComponent:0.14];
    betaLabel.layer.cornerRadius = 9.0;
    betaLabel.layer.cornerCurve = kCACornerCurveContinuous;
    betaLabel.layer.masksToBounds = YES;
    betaLabel.textAlignment = NSTextAlignmentCenter;
    [betaLabel.heightAnchor constraintEqualToConstant:18.0].active = YES;

    UIStackView *heroStack = [[UIStackView alloc] initWithArrangedSubviews:@[hero, headline, betaLabel, subheadline]];
    heroStack.axis = UILayoutConstraintAxisVertical;
    heroStack.alignment = UIStackViewAlignmentCenter;
    heroStack.spacing = 10.0;
    [heroStack setCustomSpacing:16.0 afterView:hero];
    [heroStack setCustomSpacing:8.0 afterView:headline];
    [heroStack setCustomSpacing:12.0 afterView:betaLabel];

    // --- Feature rows ---
    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    UIStackView *rowStack = [[UIStackView alloc] init];
    rowStack.axis = UILayoutConstraintAxisVertical;
    rowStack.spacing = 20.0;
    rowStack.layoutMarginsRelativeArrangement = YES;
    rowStack.layoutMargins = UIEdgeInsetsMake(20, 18, 20, 18);

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 18.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    NSArray<SCIWhatsNewItem *> *items = self.isIntro ? [SCIWhatsNew introItems]
                                                     : [SCIWhatsNew itemsForFirstInstall:self.firstInstall];
    for (SCIWhatsNewItem *item in items) {
        UIView *row = [self rowForItem:item];

        [rows addObject:row];
        [rowStack addArrangedSubview:row];
    }

    self.animatedRows = rows;

    // --- Footnote + button ---
    UILabel *footnote = [[UILabel alloc] init];
    footnote.text = self.isIntro ? @"" : [SCIWhatsNew footnoteForFirstInstall:self.firstInstall];
    footnote.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    footnote.textColor = [UIColor tertiaryLabelColor];
    footnote.textAlignment = NSTextAlignmentCenter;
    footnote.numberOfLines = 0;

    UIButton *continueButton = [UIButton buttonWithType:UIButtonTypeSystem];

    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = self.isIntro ? SCILocalized(@"wn_intro_next") : SCILocalized(@"wn_continue");
    config.baseBackgroundColor = accent;
    config.baseForegroundColor = [UIColor whiteColor];
    config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    config.contentInsets = NSDirectionalEdgeInsetsMake(15, 20, 15, 20);
    continueButton.configuration = config;

    [continueButton addTarget:self action:@selector(continueTapped) forControlEvents:UIControlEventTouchUpInside];

    UILabel *betaNote = [[UILabel alloc] init];
    betaNote.text = SCILocalized(@"wn_beta_note");
    betaNote.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    betaNote.textColor = accent;
    betaNote.textAlignment = NSTextAlignmentCenter;
    betaNote.numberOfLines = 0;

    UIStackView *footer = [[UIStackView alloc] initWithArrangedSubviews:@[betaNote, footnote, continueButton]];
    footer.axis = UILayoutConstraintAxisVertical;
    footer.spacing = 14.0;
    footer.translatesAutoresizingMaskIntoConstraints = NO;

    // --- Scrolling body, pinned footer ---
    rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:rowStack];
    [NSLayoutConstraint activateConstraints:@[
        [rowStack.topAnchor constraintEqualToAnchor:card.topAnchor],
        [rowStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [rowStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [rowStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor]
    ]];

    UIStackView *body = [[UIStackView alloc] initWithArrangedSubviews:@[heroStack, card]];
    body.axis = UILayoutConstraintAxisVertical;
    body.spacing = 34.0;
    body.translatesAutoresizingMaskIntoConstraints = NO;

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;

    [scrollView addSubview:body];
    [self.view addSubview:scrollView];
    [self.view addSubview:footer];

    UILayoutGuide *margins = self.view.layoutMarginsGuide;

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:footer.topAnchor constant:-16.0],

        [body.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:32.0],
        [body.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24.0],
        [body.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor constant:8.0],
        [body.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor constant:-8.0],

        [footer.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor constant:8.0],
        [footer.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor constant:-8.0],
        [footer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0]
    ]];
}

- (UIView *)rowForItem:(SCIWhatsNewItem *)item {
    UIImageView *glyph = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:item.symbolName
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26.0
                                                                                  weight:UIImageSymbolWeightRegular]]];
    glyph.tintColor = item.tint ?: [SCIUtils SCIColor_Primary];
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.translatesAutoresizingMaskIntoConstraints = NO;

    // Fixed width keeps every title on the same vertical line regardless of glyph.
    [glyph.widthAnchor constraintEqualToConstant:34.0].active = YES;

    UILabel *title = [[UILabel alloc] init];
    title.text = item.title;
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.adjustsFontForContentSizeCategory = YES;
    title.numberOfLines = 0;

    UILabel *detail = [[UILabel alloc] init];
    detail.text = item.detail;
    detail.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    detail.adjustsFontForContentSizeCategory = YES;
    detail.textColor = [UIColor secondaryLabelColor];
    detail.numberOfLines = 0;

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, detail]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2.0;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[glyph, text]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentTop;
    row.spacing = 16.0;

    return row;
}

// MARK: - Animation

- (void)playEntranceAnimation {
    [self.animatedRows enumerateObjectsUsingBlock:^(UIView *row, NSUInteger index, BOOL *stop) {
        row.alpha = 0.0;
        row.transform = CGAffineTransformMakeTranslation(0, 16.0);

        [UIView animateWithDuration:0.45
                              delay:0.06 * index
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            row.alpha = 1.0;
            row.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

// MARK: - Actions

- (void)continueTapped {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];

    // Intro → hand off to the what's-new page (which is what marks the version seen).
    if (self.isIntro) {
        [self dismissViewControllerAnimated:YES completion:^{
            [SCIWhatsNewViewController presentIntro:NO fromWindow:nil];
        }];
        return;
    }

    [SCIWhatsNew markCurrentVersionSeen];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
