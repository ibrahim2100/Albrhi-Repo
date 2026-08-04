#import "SCIYTMiniPlayer.h"
#import "../../../Tweak.h"
#import "SCIYTPlayer.h"
#import "SCIYTJob.h"
#import "SCIYTThumbnails.h"
#import "../../../Localization/SCILocalize.h"


@interface SCIYTMiniPlayer ()
@property (nonatomic, strong) UIVisualEffectView *backing;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *detail;
@property (nonatomic, strong) UIButton *playPause;
@property (nonatomic, strong) UIButton *close;
@property (nonatomic, strong) UIView *progress;
@property (nonatomic, strong) NSLayoutConstraint *progressWidth;
@property (nonatomic, strong) NSTimer *tick;
@end

@implementation SCIYTMiniPlayer

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.backing = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];
    self.backing.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.backing];

    self.artwork = [[UIImageView alloc] init];
    self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    self.artwork.clipsToBounds = YES;
    self.artwork.layer.cornerRadius = 6;
    self.artwork.layer.cornerCurve = kCACornerCurveContinuous;
    self.artwork.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    self.artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.artwork];

    self.name = [[UILabel alloc] init];
    self.name.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.name.textColor = [UIColor whiteColor];

    self.detail = [[UILabel alloc] init];
    self.detail.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    self.detail.textColor = [UIColor colorWithWhite:1 alpha:0.55];

    UIStackView *words = [[UIStackView alloc] initWithArrangedSubviews:@[self.name, self.detail]];
    words.axis = UILayoutConstraintAxisVertical;
    words.spacing = 1;
    words.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:words];

    self.playPause = [self control:@"pause.fill" action:@selector(togglePlay)];
    self.close = [self control:@"xmark" action:@selector(stop)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[self.playPause, self.close]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.spacing = 4;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:buttons];

    // A hairline of progress along the top, which is how every mini bar worth copying shows
    // it -- no numbers, no scrubber, just how far in you are at a glance.
    self.progress = [[UIView alloc] init];
    self.progress.backgroundColor = SCIAccent();
    self.progress.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.progress];

    self.progressWidth = [self.progress.widthAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.backing.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.backing.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.backing.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.backing.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [self.progress.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.progress.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.progress.heightAnchor constraintEqualToConstant:2],
        self.progressWidth,

        [self.artwork.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [self.artwork.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.artwork.widthAnchor constraintEqualToConstant:40],
        [self.artwork.heightAnchor constraintEqualToConstant:40],

        [words.leadingAnchor constraintEqualToAnchor:self.artwork.trailingAnchor constant:10],
        [words.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [words.trailingAnchor constraintEqualToAnchor:buttons.leadingAnchor constant:-10],

        [buttons.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [buttons.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];

    [self addGestureRecognizer:
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reopen)]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:SCIYTPlaybackDidChangeNotification
                                               object:nil];

    [self refresh];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.tick invalidate];
}

- (UIButton *)control:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:weight]
            forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:40].active = YES;
    [button.heightAnchor constraintEqualToConstant:40].active = YES;
    return button;
}

// MARK: - What it says

- (void)refresh {
    SCIYTJob *job = [SCIYTPlayer nowPlaying];

    // Hidden rather than removed. The bar belongs to the page it is on, and taking it out of
    // the view means rebuilding it on the next tap -- for a strip that costs nothing to keep.
    BOOL show = [SCIYTPlayer isActive] && job != nil;
    self.hidden = !show;
    if (self.miniPlayerVisibilityChanged) self.miniPlayerVisibilityChanged(show);

    if (!show) {
        [self.tick invalidate];
        self.tick = nil;
        return;
    }

    self.name.text = job.title;
    self.detail.text = job.quality;
    self.artwork.image = [SCIYTThumbnails cached:job];

    BOOL playing = [SCIYTPlayer isPlaying];
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [self.playPause setImage:[UIImage systemImageNamed:(playing ? @"pause.fill" : @"play.fill")
                                     withConfiguration:weight]
                    forState:UIControlStateNormal];

    if (!self.tick) {
        // Twice a second, like the full screen's. A hairline moving smoothly is worth more
        // here than it costs, and it stops the moment the bar goes away.
        __weak __typeof(self) weakSelf = self;
        self.tick = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                    repeats:YES
                                                      block:^(__unused NSTimer *timer) {
            [weakSelf advance];
        }];
    }
}

- (void)advance {
    self.progressWidth.constant = self.bounds.size.width * [SCIYTPlayer progress];
}

// MARK: - What it does

- (void)togglePlay {
    [SCIYTPlayer toggle];
    [self refresh];
}

- (void)stop {
    [SCIYTPlayer stop];
    [self refresh];
}

- (void)reopen {
    UIViewController *host = nil;
    UIResponder *next = self;
    while ((next = next.nextResponder)) {
        if ([next isKindOfClass:[UIViewController class]]) { host = (UIViewController *)next; break; }
    }

    // Up the responder chain rather than through a stored controller. The bar is a view; the
    // screen it is on is whatever it was added to, and asking is more honest than remembering.
    [SCIYTPlayer reopenFrom:host];
}

@end
