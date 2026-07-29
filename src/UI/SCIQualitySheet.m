#import "SCIQualitySheet.h"
#import "../Utils.h"
#import "../InstagramHeaders.h"
#import "../Localization/SCILocalize.h"

@interface SCIQualitySheetController : UIViewController
@property (nonatomic, strong) NSArray<NSDictionary *> *options;
@property (nonatomic, copy) void (^onChosen)(long long height);
@property (nonatomic, strong) UIView *card;
@property (nonatomic, assign) BOOL answered;
@end

@implementation SCIQualitySheetController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.45];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [self buildCard];
}

/// "1440p · 2K" — the number people know, plus the name they know it by.
+ (NSString *)labelForHeight:(long long)height width:(long long)width {
    long long shortSide = MIN(height, width);

    NSString *name = nil;
    if (shortSide >= 2160) name = @"4K";
    else if (shortSide >= 1440) name = @"2K";
    else if (shortSide >= 1080) name = @"Full HD";
    else if (shortSide >= 720) name = @"HD";

    NSString *base = [NSString stringWithFormat:@"%lldp", shortSide];
    return name ? [NSString stringWithFormat:@"%@  ·  %@", base, name] : base;
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
    title.text = SCILocalized(@"quality_title");
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [self.card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = SCILocalized(@"quality_body");
    subtitle.font = [UIFont systemFontOfSize:12.5];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [self.card addSubview:subtitle];

    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 8;

    for (NSUInteger i = 0; i < self.options.count; i++) {
        [rows addArrangedSubview:[self rowForOption:self.options[i] highest:(i == 0)]];
    }
    [self.card addSubview:rows];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel.translatesAutoresizingMaskIntoConstraints = NO;
    cancel.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.18];
    cancel.layer.cornerRadius = 15;
    cancel.layer.cornerCurve = kCACornerCurveContinuous;
    cancel.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [cancel setTitle:SCILocalized(@"cancel") forState:UIControlStateNormal];
    [cancel setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    [cancel addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:cancel];

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

        [title.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-20],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [rows.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18],
        [rows.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [rows.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],

        [cancel.topAnchor constraintEqualToAnchor:rows.bottomAnchor constant:14],
        [cancel.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14],
        [cancel.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        [cancel.heightAnchor constraintEqualToConstant:48],
        [cancel.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-18]
    ]];
}

- (UIView *)rowForOption:(NSDictionary *)option highest:(BOOL)highest {
    UIColor *accent = [SCIUtils SCIColor_Primary];

    long long height = [option[@"height"] longLongValue];
    long long width = [option[@"width"] longLongValue];
    long long bandwidth = [option[@"bandwidth"] longLongValue];
    double duration = [option[@"duration"] doubleValue];

    UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = highest ? [accent colorWithAlphaComponent:0.16]
                                  : [UIColor.systemGrayColor colorWithAlphaComponent:0.14];
    row.layer.cornerRadius = 16;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    row.tag = (NSInteger)height;
    [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = [SCIQualitySheetController labelForHeight:height width:width];
    name.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    name.textColor = highest ? accent : UIColor.labelColor;
    name.userInteractionEnabled = NO;
    [row addSubview:name];

    // An approximate size, from the rendition's own bitrate and the clip's length.
    // Worth showing precisely because the reason to pick a lower rung is usually
    // that the top one is bigger and slower than the moment calls for.
    UILabel *detail = [[UILabel alloc] init];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    detail.font = [UIFont systemFontOfSize:12];
    detail.textColor = UIColor.secondaryLabelColor;
    detail.userInteractionEnabled = NO;

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    // Frame rate first: at one resolution it is the difference people actually feel,
    // and a 60 fps rung is worth waiting longer for in a way a higher bitrate is not.
    int fps = (int)round([option[@"fps"] doubleValue]);
    if (fps > 0) [parts addObject:[NSString stringWithFormat:@"%d fps", fps]];

    if (bandwidth > 0) {
        [parts addObject:[NSString stringWithFormat:@"%.1f Mbps", bandwidth / 1000000.0]];
    }
    if (bandwidth > 0 && duration > 0) {
        [parts addObject:[NSString stringWithFormat:@"≈ %.1f MB", (bandwidth / 8.0 * duration) / 1000000.0]];
    }
    if (highest) [parts addObject:SCILocalized(@"quality_best")];

    detail.text = [parts componentsJoinedByString:@"  ·  "];
    [row addSubview:detail];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:58],
        [name.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [name.topAnchor constraintEqualToAnchor:row.topAnchor constant:11],
        [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2]
    ]];

    return row;
}

// MARK: - Appearance

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    self.card.transform = CGAffineTransformMakeTranslation(0, self.card.bounds.size.height + 40);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.85
          initialSpringVelocity:0.6 options:0 animations:^{
        self.card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

// MARK: - Answers

- (void)rowTapped:(UIButton *)sender {
    if (self.answered) return;
    self.answered = YES;

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    long long height = (long long)sender.tag;
    void (^handler)(long long) = self.onChosen;

    [self dismissViewControllerAnimated:YES completion:nil];
    if (handler) handler(height);
}

- (void)cancelTapped {
    if (self.answered) return;
    self.answered = YES;

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap {
    if (CGRectContainsPoint(self.card.frame, [tap locationInView:self.view])) return;

    [self cancelTapped];
}

@end


@implementation SCIQualitySheet

+ (void)presentWithOptions:(NSArray<NSDictionary *> *)options
                    chosen:(void (^)(long long))chosen {

    if (options.count == 0) return;

    SCIQualitySheetController *sheet = [[SCIQualitySheetController alloc] init];
    sheet.options = options;
    sheet.onChosen = chosen;
    sheet.modalPresentationStyle = UIModalPresentationOverFullScreen;
    sheet.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [topMostController() presentViewController:sheet animated:YES completion:nil];
}

@end
