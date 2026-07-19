#import "SCIDownloadCell.h"
#import "../../Localization/SCILocalize.h"

static CGFloat const SCITileSize = 42.0;
static CGFloat const SCIRingSize = 30.0;
static CGFloat const SCIRingWidth = 2.5;

@interface SCIDownloadCell ()

@property (nonatomic, strong) UIImageView *glyphView;
@property (nonatomic, strong) UIView *tileView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *actionButton;

@property (nonatomic, strong) CAShapeLayer *trackLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;

@property (nonatomic, strong) UIColor *accentColor;

@end

@implementation SCIDownloadCell

+ (NSString *)reuseIdentifier {
    return @"SCIDownloadCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    [self buildHierarchy];

    return self;
}

- (void)buildHierarchy {
    self.selectionStyle = UITableViewCellSelectionStyleDefault;

    // Tinted glyph tile
    _tileView = [[UIView alloc] init];
    _tileView.layer.cornerRadius = 10.0;
    _tileView.layer.cornerCurve = kCACornerCurveContinuous;
    _tileView.translatesAutoresizingMaskIntoConstraints = NO;

    _glyphView = [[UIImageView alloc] init];
    _glyphView.contentMode = UIViewContentModeScaleAspectFit;
    _glyphView.translatesAutoresizingMaskIntoConstraints = NO;

    [_tileView addSubview:_glyphView];
    [self.contentView addSubview:_tileView];

    // Labels
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _statusLabel.adjustsFontForContentSizeCategory = YES;
    _statusLabel.textColor = [UIColor secondaryLabelColor];
    _statusLabel.numberOfLines = 1;

    UIStackView *labelStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _statusLabel]];
    labelStack.axis = UILayoutConstraintAxisVertical;
    labelStack.spacing = 2.0;
    labelStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:labelStack];

    // Trailing control — progress ring wrapping a glyph
    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];

    _trackLayer = [CAShapeLayer layer];
    _trackLayer.fillColor = UIColor.clearColor.CGColor;
    _trackLayer.lineWidth = SCIRingWidth;
    _trackLayer.strokeColor = [UIColor systemFillColor].CGColor;

    _progressLayer = [CAShapeLayer layer];
    _progressLayer.fillColor = UIColor.clearColor.CGColor;
    _progressLayer.lineWidth = SCIRingWidth;
    _progressLayer.lineCap = kCALineCapRound;
    _progressLayer.strokeEnd = 0.0;

    [_actionButton.layer addSublayer:_trackLayer];
    [_actionButton.layer addSublayer:_progressLayer];

    [self.contentView addSubview:_actionButton];

    [NSLayoutConstraint activateConstraints:@[
        [_tileView.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [_tileView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_tileView.widthAnchor constraintEqualToConstant:SCITileSize],
        [_tileView.heightAnchor constraintEqualToConstant:SCITileSize],

        [_glyphView.centerXAnchor constraintEqualToAnchor:_tileView.centerXAnchor],
        [_glyphView.centerYAnchor constraintEqualToAnchor:_tileView.centerYAnchor],

        [labelStack.leadingAnchor constraintEqualToAnchor:_tileView.trailingAnchor constant:12.0],
        [labelStack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [labelStack.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor constant:-12.0],
        [labelStack.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:10.0],

        [_actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_actionButton.widthAnchor constraintEqualToConstant:SCIRingSize],
        [_actionButton.heightAnchor constraintEqualToConstant:SCIRingSize]
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // The ring starts at 12 o'clock and sweeps clockwise.
    CGRect bounds = self.actionButton.bounds;
    CGFloat radius = (CGRectGetWidth(bounds) - SCIRingWidth) / 2.0;

    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
                                                        radius:radius
                                                    startAngle:-M_PI_2
                                                      endAngle:(3.0 * M_PI_2)
                                                     clockwise:YES];

    self.trackLayer.frame = bounds;
    self.progressLayer.frame = bounds;
    self.trackLayer.path = path.CGPath;
    self.progressLayer.path = path.CGPath;
}

// MARK: - Configuration

- (void)configureWithJob:(SCIDownloadJob *)job accentColor:(UIColor *)accent {
    _job = job;
    _accentColor = accent;

    self.titleLabel.text = job.displayName;

    UIColor *tint = [self tintForState:job.state accent:accent];

    self.tileView.backgroundColor = [tint colorWithAlphaComponent:0.15];
    self.glyphView.tintColor = tint;
    self.glyphView.image = [UIImage systemImageNamed:[job symbolName]
                                   withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19.0
                                                                                                     weight:UIImageSymbolWeightRegular]];

    self.progressLayer.strokeColor = tint.CGColor;

    [self applyProgressFromJob:job];
}

- (void)applyProgressFromJob:(SCIDownloadJob *)job {
    _job = job;

    self.statusLabel.text = [job statusDescription];
    self.statusLabel.textColor = (job.state == SCIDownloadStateFailed)
        ? [UIColor systemRedColor]
        : [UIColor secondaryLabelColor];

    BOOL showsRing = (job.state == SCIDownloadStateDownloading || job.state == SCIDownloadStatePaused);

    self.trackLayer.hidden = !showsRing;
    self.progressLayer.hidden = !showsRing;
    self.progressLayer.strokeEnd = showsRing ? job.progress : 0.0;

    NSString *glyph = [self actionGlyphForState:job.state];

    self.actionButton.hidden = (glyph == nil);
    self.actionButton.accessibilityLabel = [self actionAccessibilityLabelForState:job.state];

    if (glyph) {
        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:(showsRing ? 11.0 : 16.0)
                                                            weight:UIImageSymbolWeightBold];

        [self.actionButton setImage:[UIImage systemImageNamed:glyph withConfiguration:config]
                           forState:UIControlStateNormal];

        self.actionButton.tintColor = [self tintForState:job.state accent:self.accentColor];
    }
}

- (UIColor *)tintForState:(SCIDownloadState)state accent:(UIColor *)accent {
    switch (state) {
        case SCIDownloadStateCompleted: return [UIColor systemGreenColor];
        case SCIDownloadStateFailed:    return [UIColor systemRedColor];
        case SCIDownloadStateCancelled: return [UIColor systemGrayColor];
        case SCIDownloadStatePaused:    return [UIColor systemOrangeColor];
        default:                        return accent ?: [UIColor systemBlueColor];
    }
}

- (NSString *)actionGlyphForState:(SCIDownloadState)state {
    switch (state) {
        case SCIDownloadStateDownloading: return @"pause.fill";
        case SCIDownloadStatePaused:      return @"play.fill";
        case SCIDownloadStateQueued:      return @"xmark";
        case SCIDownloadStateFailed:
        case SCIDownloadStateCancelled:   return @"arrow.clockwise";
        case SCIDownloadStateCompleted:   return nil;  // row itself opens the file
    }
}

- (NSString *)actionAccessibilityLabelForState:(SCIDownloadState)state {
    switch (state) {
        case SCIDownloadStateDownloading: return SCILocalized(@"dl_pause");
        case SCIDownloadStatePaused:      return SCILocalized(@"dl_resume");
        case SCIDownloadStateQueued:      return SCILocalized(@"dl_cancel");
        case SCIDownloadStateFailed:
        case SCIDownloadStateCancelled:   return SCILocalized(@"dl_retry");
        default:                          return nil;
    }
}

- (void)actionTapped {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    [self.delegate downloadCellDidTapAction:self];
}

- (void)prepareForReuse {
    [super prepareForReuse];

    _job = nil;
    self.progressLayer.strokeEnd = 0.0;
}

@end
