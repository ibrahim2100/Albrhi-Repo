#import "SCIPhotoVideoSheet.h"
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"

@interface SCIPhotoVideoSheetController : UIViewController
@property (nonatomic, copy) void (^onPhoto)(void);
@property (nonatomic, copy) void (^onVideo)(NSTimeInterval);
@property (nonatomic, strong) UIStackView *durations;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, assign) NSTimeInterval chosen;
@end

@implementation SCIPhotoVideoSheetController

// The lengths on offer. Ninety is the ceiling: beyond it the wait outweighs the
// result, and reel audio can run for minutes.
static const NSInteger kLengths[] = { 5, 10, 15, 30, 60, 90 };
static const NSInteger kLengthCount = 6;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.45];
    self.chosen = 10;   // the length most people want, preselected

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

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = SCILocalized(@"photovid_sheet_title");
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = SCILocalized(@"photovid_sheet_body");
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;

    // The two outcomes, side by side and equally weighted, so neither reads as
    // the thing being pushed.
    UIView *photoOption = [self optionWithSymbol:@"photo"
                                           title:SCILocalized(@"photovid_opt_photo")
                                        subtitle:SCILocalized(@"photovid_opt_photo_sub")
                                            tint:UIColor.systemGrayColor
                                          action:@selector(choosePhoto)];

    UIView *videoOption = [self optionWithSymbol:@"music.note.tv"
                                           title:SCILocalized(@"photovid_opt_video")
                                        subtitle:SCILocalized(@"photovid_opt_video_sub")
                                            tint:[SCIUtils SCIColor_Primary]
                                          action:@selector(chooseVideo)];

    UIStackView *options = [[UIStackView alloc] initWithArrangedSubviews:@[photoOption, videoOption]];
    options.translatesAutoresizingMaskIntoConstraints = NO;
    options.axis = UILayoutConstraintAxisHorizontal;
    options.distribution = UIStackViewDistributionFillEqually;
    options.spacing = 12;

    // Lengths, hidden until a clip is what the user wants.
    self.durations = [[UIStackView alloc] init];
    self.durations.translatesAutoresizingMaskIntoConstraints = NO;
    self.durations.axis = UILayoutConstraintAxisHorizontal;
    self.durations.distribution = UIStackViewDistributionFillEqually;
    self.durations.spacing = 8;
    self.durations.hidden = YES;
    self.durations.alpha = 0;

    for (NSInteger i = 0; i < kLengthCount; i++) {
        [self.durations addArrangedSubview:[self chipForSeconds:kLengths[i]]];
    }

    [self.card addSubview:title];
    [self.card addSubview:subtitle];
    [self.card addSubview:options];
    [self.card addSubview:self.durations];

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

        [title.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:14],
        [title.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-20],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [options.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18],
        [options.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [options.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],

        [self.durations.topAnchor constraintEqualToAnchor:options.bottomAnchor constant:14],
        [self.durations.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [self.durations.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        [self.durations.heightAnchor constraintEqualToConstant:40],
        [self.durations.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-18]
    ]];

}

// The offset is set here rather than in viewDidLoad: the card has no height until
// it has been laid out, and a zero offset means no animation at all.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    self.card.transform = CGAffineTransformMakeTranslation(0, self.card.bounds.size.height + 40);
}

- (UIView *)optionWithSymbol:(NSString *)symbol
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                        tint:(UIColor *)tint
                      action:(SEL)action {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [tint colorWithAlphaComponent:0.13];
    button.layer.cornerRadius = 16;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = tint;
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = title;
    name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    name.textAlignment = NSTextAlignmentCenter;

    UILabel *detail = [[UILabel alloc] init];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    detail.text = subtitle;
    detail.font = [UIFont systemFontOfSize:11];
    detail.textColor = UIColor.secondaryLabelColor;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.numberOfLines = 2;

    for (UIView *v in @[icon, name, detail]) {
        v.userInteractionEnabled = NO;
        [button addSubview:v];
    }

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:button.topAnchor constant:16],
        [icon.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:26],
        [icon.heightAnchor constraintEqualToConstant:26],

        [name.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:8],
        [name.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:8],
        [name.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-8],

        [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2],
        [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [detail.trailingAnchor constraintEqualToAnchor:name.trailingAnchor],
        [detail.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-14]
    ]];

    return button;
}

- (UIButton *)chipForSeconds:(NSInteger)seconds {
    UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
    chip.tag = seconds;
    chip.layer.cornerRadius = 13;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    chip.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [chip setTitle:[NSString stringWithFormat:@"%lds", (long)seconds] forState:UIControlStateNormal];
    [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];

    [self styleChip:chip selected:(seconds == (NSInteger)self.chosen)];
    return chip;
}

- (void)styleChip:(UIButton *)chip selected:(BOOL)selected {
    UIColor *accent = [SCIUtils SCIColor_Primary];
    chip.backgroundColor = selected ? accent : [UIColor.systemGrayColor colorWithAlphaComponent:0.18];
    [chip setTitleColor:selected ? UIColor.whiteColor : UIColor.labelColor forState:UIControlStateNormal];
}

- (void)chipTapped:(UIButton *)chip {
    self.chosen = chip.tag;

    for (UIView *view in self.durations.arrangedSubviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            [self styleChip:(UIButton *)view selected:(view.tag == chip.tag)];
        }
    }

    [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}

// MARK: - Choices

- (void)choosePhoto {
    void (^handler)(void) = self.onPhoto;
    [self dismissViewControllerAnimated:YES completion:^{ if (handler) handler(); }];
}

- (void)chooseVideo {
    // First tap reveals the lengths; the second confirms one. The default is
    // already selected, so it is two taps at most either way.
    if (self.durations.hidden) {
        self.durations.hidden = NO;

        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.85
              initialSpringVelocity:0.3 options:0 animations:^{
            self.durations.alpha = 1;
            [self.view layoutIfNeeded];
        } completion:nil];
        return;
    }

    NSTimeInterval seconds = self.chosen;
    void (^handler)(NSTimeInterval) = self.onVideo;
    [self dismissViewControllerAnimated:YES completion:^{ if (handler) handler(seconds); }];
}

// A second recogniser on the card would still let this one fire — two taps in
// different views both recognise by default — so the card is ruled out by where
// the touch landed instead.
- (void)backgroundTapped:(UITapGestureRecognizer *)tap {
    if (CGRectContainsPoint(self.card.frame, [tap locationInView:self.view])) return;
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Presentation

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.82
          initialSpringVelocity:0.5 options:0 animations:^{
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end


@implementation SCIPhotoVideoSheet

+ (void)presentWithOnPhoto:(void (^)(void))onPhoto
                   onVideo:(void (^)(NSTimeInterval))onVideo {

    SCIPhotoVideoSheetController *sheet = [[SCIPhotoVideoSheetController alloc] init];
    sheet.onPhoto = onPhoto;
    sheet.onVideo = onVideo;
    sheet.modalPresentationStyle = UIModalPresentationOverFullScreen;
    sheet.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [topMostController() presentViewController:sheet animated:YES completion:nil];
}

@end
