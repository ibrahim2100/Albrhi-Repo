#import "SCIYTPlayer.h"
#import "SCIYTThumbnails.h"
#import "SCIYTIcon.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>

static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

/// How long the controls stay up once you stop touching them.
static const NSTimeInterval kSCIChromeLinger = 3.5;

/// How far a double tap moves you, in seconds. Ten, which is what every player that has
/// this gesture uses -- a number people already know without being told.
static const double kSCINudge = 10;

@interface SCIYTPlayer () <AVPictureInPictureControllerDelegate>
@property (nonatomic, strong) NSArray<SCIYTJob *> *jobs;
@property (nonatomic) NSUInteger index;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *layer;
@property (nonatomic, strong) AVPictureInPictureController *pip;
@property (nonatomic, strong) id ticker;

@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) UIImageView *backdrop;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIView *chrome;
@property (nonatomic, strong) CAGradientLayer *scrim;

@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *subtitle;
@property (nonatomic, strong) UILabel *elapsed;
@property (nonatomic, strong) UILabel *remaining;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UIButton *playPause;
@property (nonatomic, strong) UIButton *pipButton;
@property (nonatomic, strong) UIButton *close;

@property (nonatomic, strong) NSLayoutConstraint *stageBottomToChrome;
@property (nonatomic, strong) NSLayoutConstraint *stageBottomToView;

@property (nonatomic) BOOL scrubbing;
@property (nonatomic) BOOL chromeHidden;
@property (nonatomic, strong) NSTimer *linger;

@property (nonatomic, strong) id nextToken;
@property (nonatomic, strong) id previousToken;
@property (nonatomic, strong) id positionToken;
@property (nonatomic, strong) id forwardToken;
@property (nonatomic, strong) id backwardToken;
@property (nonatomic) BOOL torndown;
@property (nonatomic) BOOL publishedLength;
@end

@implementation SCIYTPlayer

+ (void)presentFrom:(UIViewController *)presenter
               jobs:(NSArray<SCIYTJob *> *)jobs
              start:(NSUInteger)index {

    if (!presenter || index >= jobs.count) return;

    SCIYTPlayer *player = [[SCIYTPlayer alloc] init];
    player.jobs = jobs;
    player.index = index;
    player.modalPresentationStyle = UIModalPresentationFullScreen;

    [presenter presentViewController:player animated:YES completion:nil];
}

/// Turns with the phone, unlike the sheet it was presented from.
///
/// The video used to shrink the moment you rotated: the screen went landscape, the layout
/// did not, and a picture sized for a column ended up in the middle of a wide black field.
/// Allowing every orientation is half of it -- the other half is that the layout changes
/// shape, further down.
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)prefersStatusBarHidden { return self.chromeHidden; }
- (BOOL)prefersHomeIndicatorAutoHidden { return self.chromeHidden; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

// MARK: - Building it

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    NSError *audioError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioError];
    [[AVAudioSession sharedInstance] setActive:YES error:&audioError];
    if (audioError) SCILogV(@"player: audio session — %@", audioError.localizedDescription);

    [self buildStage];
    [self buildChrome];
    [self buildGestures];
    [self wireRemote];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wentAway)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cameBack)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    [self load];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.movingFromParentViewController) [self teardown];
}

- (void)dealloc {
    [self teardown];
}

- (void)teardown {
    if (self.torndown) return;
    self.torndown = YES;

    [self.linger invalidate];
    self.linger = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (self.ticker) {
        [self.player removeTimeObserver:self.ticker];
        self.ticker = nil;
    }

    [self.player pause];
    self.pip = nil;
    self.layer.player = nil;

    MPRemoteCommandCenter *centre = [MPRemoteCommandCenter sharedCommandCenter];
    [centre.playCommand removeTarget:self];
    [centre.pauseCommand removeTarget:self];
    if (self.nextToken) { [centre.nextTrackCommand removeTarget:self.nextToken]; self.nextToken = nil; }
    if (self.previousToken) { [centre.previousTrackCommand removeTarget:self.previousToken]; self.previousToken = nil; }
    if (self.positionToken) { [centre.changePlaybackPositionCommand removeTarget:self.positionToken]; self.positionToken = nil; }
    if (self.forwardToken) { [centre.skipForwardCommand removeTarget:self.forwardToken]; self.forwardToken = nil; }
    if (self.backwardToken) { [centre.skipBackwardCommand removeTarget:self.backwardToken]; self.backwardToken = nil; }

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;

    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
}

/// The picture, and what stands in for it when there is none.
///
/// A song gets its own cover blown up and blurred behind it. It is the one thing that makes
/// an audio screen look like a player rather than a file open in a viewer, and it costs one
/// image that is already on disk.
- (void)buildStage {
    self.backdrop = [[UIImageView alloc] init];
    self.backdrop.contentMode = UIViewContentModeScaleAspectFill;
    self.backdrop.clipsToBounds = YES;
    self.backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.backdrop];

    self.blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    self.blur.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.blur];

    self.stage = [[UIView alloc] init];
    self.stage.backgroundColor = [UIColor clearColor];
    self.stage.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stage];

    self.artwork = [[UIImageView alloc] init];
    self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    self.artwork.clipsToBounds = YES;
    self.artwork.layer.cornerRadius = 14;
    self.artwork.layer.cornerCurve = kCACornerCurveContinuous;

    // A cover sitting on a blur of itself needs an edge or it dissolves into its own
    // background. A hairline and a soft drop is what lifts it off.
    self.artwork.layer.borderWidth = 0.5;
    self.artwork.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    self.artwork.layer.shadowColor = [UIColor blackColor].CGColor;
    self.artwork.layer.shadowOpacity = 0.45;
    self.artwork.layer.shadowRadius = 24;
    self.artwork.layer.shadowOffset = CGSizeMake(0, 12);
    self.artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self.stage addSubview:self.artwork];

    [NSLayoutConstraint activateConstraints:@[
        [self.backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.blur.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.blur.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.blur.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.blur.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.stage.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.stage.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.stage.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.artwork.centerXAnchor constraintEqualToAnchor:self.stage.centerXAnchor],
        [self.artwork.centerYAnchor constraintEqualToAnchor:self.stage.centerYAnchor],
        [self.artwork.widthAnchor constraintLessThanOrEqualToAnchor:self.stage.widthAnchor multiplier:0.78],
        [self.artwork.heightAnchor constraintLessThanOrEqualToAnchor:self.stage.heightAnchor multiplier:0.78],
        [self.artwork.widthAnchor constraintEqualToAnchor:self.artwork.heightAnchor]
    ]];

    // Both kept, one active at a time. Rotating changes which -- in landscape the picture
    // takes the whole screen and the controls float over it, which is what a video wants
    // and what the old fixed layout could not do.
    self.stageBottomToView = [self.stage.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];

    self.layer = [AVPlayerLayer layer];
    self.layer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.stage.layer addSublayer:self.layer];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.layer.frame = self.stage.bounds;
    self.scrim.frame = self.chrome.bounds;
    [self applyShape];
}

/// Which of the two layouts applies, decided from the shape of the screen.
- (void)applyShape {
    BOOL wide = self.view.bounds.size.width > self.view.bounds.size.height;

    if (wide == self.stageBottomToView.isActive) return;

    self.stageBottomToChrome.active = !wide;
    self.stageBottomToView.active = wide;

    // Over the video, the controls need something behind them or white text lands on a
    // white frame. In portrait they sit on their own ground and need nothing.
    self.scrim.hidden = !wide;
    self.chrome.backgroundColor = [UIColor clearColor];
}

- (void)buildChrome {
    self.chrome = [[UIView alloc] init];
    self.chrome.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chrome];

    self.scrim = [CAGradientLayer layer];
    self.scrim.colors = @[(id)[UIColor clearColor].CGColor,
                          (id)[UIColor colorWithWhite:0 alpha:0.75].CGColor];
    self.scrim.hidden = YES;
    [self.chrome.layer insertSublayer:self.scrim atIndex:0];

    self.name = [[UILabel alloc] init];
    self.name.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    self.name.textColor = [UIColor whiteColor];
    self.name.textAlignment = NSTextAlignmentCenter;
    self.name.numberOfLines = 2;

    self.subtitle = [[UILabel alloc] init];
    self.subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    self.subtitle.textAlignment = NSTextAlignmentCenter;

    self.scrubber = [[UISlider alloc] init];
    self.scrubber.minimumTrackTintColor = SCIAccent();
    self.scrubber.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.22];

    // A smaller thumb than the system default, which is sized for a volume slider and looks
    // clumsy on a timeline. Grown while dragging so the finger has something to hold.
    [self.scrubber setThumbImage:[self thumbOfSize:12] forState:UIControlStateNormal];
    [self.scrubber setThumbImage:[self thumbOfSize:20] forState:UIControlStateHighlighted];

    [self.scrubber addTarget:self action:@selector(scrubStarted)
            forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubEnded)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];

    self.elapsed = [self timeLabel:NSTextAlignmentLeft];
    self.remaining = [self timeLabel:NSTextAlignmentRight];

    UIStackView *times = [[UIStackView alloc] initWithArrangedSubviews:@[self.elapsed, self.remaining]];
    times.axis = UILayoutConstraintAxisHorizontal;
    times.distribution = UIStackViewDistributionFillEqually;

    UIButton *back = [self control:@"gobackward.10" size:24 action:@selector(nudgeBack)];
    UIButton *previous = [self control:@"backward.end.fill" size:22 action:@selector(previous)];
    self.playPause = [self control:@"pause.circle.fill" size:56 action:@selector(togglePlay)];
    UIButton *next = [self control:@"forward.end.fill" size:22 action:@selector(next)];
    UIButton *ahead = [self control:@"goforward.10" size:24 action:@selector(nudgeAhead)];

    UIStackView *transport = [[UIStackView alloc] initWithArrangedSubviews:
        @[previous, back, self.playPause, ahead, next]];
    transport.axis = UILayoutConstraintAxisHorizontal;
    transport.distribution = UIStackViewDistributionEqualCentering;
    transport.alignment = UIStackViewAlignmentCenter;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
        @[self.name, self.subtitle, self.scrubber, times, transport]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    [stack setCustomSpacing:18 afterView:self.subtitle];
    [stack setCustomSpacing:14 afterView:times];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chrome addSubview:stack];

    self.close = [self control:@"chevron.down" size:18 action:@selector(close)];
    self.close.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.close];

    self.pipButton = [self control:@"pip.enter" size:18 action:@selector(enterPiP)];
    self.pipButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.pipButton.hidden = YES;
    [self.view addSubview:self.pipButton];

    self.stageBottomToChrome =
        [self.stage.bottomAnchor constraintEqualToAnchor:self.chrome.topAnchor constant:-8];
    self.stageBottomToChrome.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.chrome.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.chrome.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.chrome.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:self.chrome.topAnchor constant:14],
        [stack.leadingAnchor constraintEqualToAnchor:self.chrome.leadingAnchor constant:26],
        [stack.trailingAnchor constraintEqualToAnchor:self.chrome.trailingAnchor constant:-26],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18],

        [self.close.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6],
        [self.close.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [self.close.widthAnchor constraintEqualToConstant:44],
        [self.close.heightAnchor constraintEqualToConstant:44],

        [self.pipButton.centerYAnchor constraintEqualToAnchor:self.close.centerYAnchor],
        [self.pipButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [self.pipButton.widthAnchor constraintEqualToConstant:44],
        [self.pipButton.heightAnchor constraintEqualToConstant:44]
    ]];
}

/// Tap anywhere to show or hide; double tap a side to jump.
///
/// The single tap waits on the double, or every jump would flash the controls on its way.
- (void)buildGestures {
    UITapGestureRecognizer *once =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleChrome)];

    UITapGestureRecognizer *twice =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapped:)];
    twice.numberOfTapsRequired = 2;

    [once requireGestureRecognizerToFail:twice];

    [self.stage addGestureRecognizer:once];
    [self.stage addGestureRecognizer:twice];
    self.stage.userInteractionEnabled = YES;
}

- (UIImage *)thumbOfSize:(CGFloat)size {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];

    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        [[UIColor whiteColor] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)] fill];
    }];
}

- (UILabel *)timeLabel:(NSTextAlignment)alignment {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    label.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    label.textAlignment = alignment;
    label.text = @"--:--";
    return label;
}

- (UIButton *)control:(NSString *)symbol size:(CGFloat)size action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:weight]
            forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// MARK: - Showing and hiding

- (void)toggleChrome {
    [self setChromeHidden:!self.chromeHidden animated:YES];
}

- (void)setChromeHidden:(BOOL)hidden animated:(BOOL)animated {
    _chromeHidden = hidden;

    void (^apply)(void) = ^{
        CGFloat alpha = hidden ? 0 : 1;
        self.chrome.alpha = alpha;
        self.close.alpha = alpha;
        self.pipButton.alpha = alpha;
    };

    if (animated) {
        [UIView animateWithDuration:0.25 animations:apply];
    } else {
        apply();
    }

    [self setNeedsStatusBarAppearanceUpdate];
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    [self restartLinger];
}

/// Hides the controls again after a while, but only while something is playing.
///
/// Paused, they stay: a paused screen with no controls looks broken, and the reason to hide
/// them is to see the picture move.
- (void)restartLinger {
    [self.linger invalidate];
    self.linger = nil;

    if (self.chromeHidden || self.player.rate == 0) return;
    if ([self current].kind != SCIYTJobKindVideo) return;

    __weak __typeof(self) weakSelf = self;
    self.linger = [NSTimer scheduledTimerWithTimeInterval:kSCIChromeLinger
                                                  repeats:NO
                                                    block:^(__unused NSTimer *timer) {
        [weakSelf setChromeHidden:YES animated:YES];
    }];
}

- (void)doubleTapped:(UITapGestureRecognizer *)tap {
    CGPoint at = [tap locationInView:self.stage];
    BOOL ahead = at.x > CGRectGetMidX(self.stage.bounds);
    [self skipBy:ahead ? kSCINudge : -kSCINudge];
}

- (void)nudgeBack { [self skipBy:-kSCINudge]; }
- (void)nudgeAhead { [self skipBy:kSCINudge]; }

// MARK: - The queue

- (SCIYTJob *)current {
    return (self.index < self.jobs.count) ? self.jobs[self.index] : nil;
}

- (void)load {
    SCIYTJob *job = [self current];
    NSURL *file = [job fileURL];

    if (!file) {
        if (self.index + 1 < self.jobs.count) { self.index++; [self load]; return; }
        [self close];
        return;
    }

    if (self.ticker) { [self.player removeTimeObserver:self.ticker]; self.ticker = nil; }

    self.player = [AVPlayer playerWithURL:file];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachedEnd)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];

    BOOL isVideo = (job.kind == SCIYTJobKindVideo);
    self.layer.player = isVideo ? self.player : nil;

    UIImage *still = [SCIYTThumbnails cached:job];
    self.artwork.image = still;
    self.artwork.hidden = isVideo || !still;
    self.backdrop.image = still;
    self.blur.hidden = isVideo;
    self.backdrop.hidden = isVideo;

    self.name.text = job.title;
    self.subtitle.text = job.quality;
    self.scrubber.value = 0;
    self.publishedLength = NO;

    [self preparePiP:isVideo];

    __weak __typeof(self) weakSelf = self;
    self.ticker = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                            queue:dispatch_get_main_queue()
                                                       usingBlock:^(__unused CMTime time) {
        [weakSelf tick];
    }];

    [self.player play];
    [self showPlaying:YES];
    [self setChromeHidden:NO animated:NO];
    [self describeToLockScreen];
}

- (void)next {
    if (self.index + 1 >= self.jobs.count) { [self.player pause]; [self showPlaying:NO]; return; }
    self.index++;
    [self load];
}

- (void)previous {
    if (CMTimeGetSeconds(self.player.currentTime) > 3 || self.index == 0) {
        [self seekTo:0];
        return;
    }
    self.index--;
    [self load];
}

- (void)reachedEnd { [self next]; }

- (void)togglePlay {
    BOOL playing = (self.player.rate > 0);
    if (playing) [self.player pause]; else [self.player play];
    [self showPlaying:!playing];
    [self describeToLockScreen];
    [self restartLinger];
}

- (void)showPlaying:(BOOL)playing {
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:56 weight:UIImageSymbolWeightMedium];
    [self.playPause setImage:[UIImage systemImageNamed:(playing ? @"pause.circle.fill" : @"play.circle.fill")
                                     withConfiguration:weight]
                    forState:UIControlStateNormal];
}

- (void)close {
    [self.player pause];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Picture in picture

- (void)preparePiP:(BOOL)isVideo {
    if (!isVideo || ![AVPictureInPictureController isPictureInPictureSupported]) {
        self.pip = nil;
        self.pipButton.hidden = YES;
        return;
    }

    self.pip = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.layer];
    self.pip.delegate = self;
    self.pipButton.hidden = NO;
}

- (void)enterPiP {
    if (self.pip.isPictureInPictureActive) {
        [self.pip stopPictureInPicture];
        return;
    }
    [self.pip startPictureInPicture];
}

/// Put back the way it was found.
///
/// Without this the player is left dismissed underneath the little window, and closing the
/// window leaves nothing to go back to.
- (void)pictureInPictureControllerWillStopPictureInPicture:(__unused AVPictureInPictureController *)controller {
    [self setChromeHidden:NO animated:NO];
}

// MARK: - The scrubber

- (void)scrubStarted {
    self.scrubbing = YES;
    [self.linger invalidate];
}

- (void)scrubEnded {
    self.scrubbing = NO;

    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;

    [self seekTo:self.scrubber.value * length];
    [self restartLinger];
}

- (void)seekTo:(double)seconds {
    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;

    double target = MIN(MAX(seconds, 0), length);

    __weak __typeof(self) weakSelf = self;
    [self.player seekToTime:CMTimeMakeWithSeconds(target, 600)
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero
          completionHandler:^(BOOL finished) {
        if (finished) [weakSelf describeToLockScreen];
    }];
}

- (void)skipBy:(double)seconds {
    [self seekTo:CMTimeGetSeconds(self.player.currentTime) + seconds];
}

- (void)tick {
    double at = CMTimeGetSeconds(self.player.currentTime);
    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;

    if (!self.publishedLength) {
        self.publishedLength = YES;
        [self describeToLockScreen];
        [self restartLinger];
    }

    if (self.scrubbing) return;

    self.scrubber.value = (float)(at / length);
    self.elapsed.text = [SCIYTThumbnails clock:at];
    self.remaining.text = [@"-" stringByAppendingString:[SCIYTThumbnails clock:length - at]];
}

// MARK: - Off the screen

- (void)wentAway {
    // Picture in picture is the one case where the layer must keep its player: that little
    // window *is* the layer, and handing it back an empty one closes it.
    if (self.pip.isPictureInPictureActive) return;
    if ([self current].kind == SCIYTJobKindVideo) self.layer.player = nil;
}

- (void)cameBack {
    if ([self current].kind == SCIYTJobKindVideo) self.layer.player = self.player;
}

// MARK: - The lock screen

- (void)wireRemote {
    MPRemoteCommandCenter *centre = [MPRemoteCommandCenter sharedCommandCenter];

    centre.playCommand.enabled = YES;
    centre.pauseCommand.enabled = YES;
    centre.changePlaybackPositionCommand.enabled = YES;

    // Next and previous, or fifteen seconds -- never both, because iOS will not show both.
    //
    // Claiming the skip pair *replaces* next and previous on the lock screen, which is what
    // 0.15.0 did without meaning to: it added the skips and quietly took away the two
    // buttons that move between saved videos. Track buttons are the default now and the
    // jumps are the setting, which is the way round it should always have been.
    BOOL jumps = SCIPrefEnabled(SCIPrefLockScreenSkip);

    centre.nextTrackCommand.enabled = !jumps;
    centre.previousTrackCommand.enabled = !jumps;
    centre.skipForwardCommand.enabled = jumps;
    centre.skipBackwardCommand.enabled = jumps;
    centre.skipForwardCommand.preferredIntervals = @[@15];
    centre.skipBackwardCommand.preferredIntervals = @[@15];

    __weak __typeof(self) weakSelf = self;

    [centre.playCommand addTarget:self action:@selector(remotePlay:)];
    [centre.pauseCommand addTarget:self action:@selector(remotePause:)];

    self.positionToken = [centre.changePlaybackPositionCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            MPChangePlaybackPositionCommandEvent *moved =
                (MPChangePlaybackPositionCommandEvent *)event;
            [weakSelf seekTo:moved.positionTime];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.nextToken = [centre.nextTrackCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(__unused MPRemoteCommandEvent *event) {
            [weakSelf next];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.previousToken = [centre.previousTrackCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(__unused MPRemoteCommandEvent *event) {
            [weakSelf previous];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.forwardToken = [centre.skipForwardCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            [weakSelf skipBy:((MPSkipIntervalCommandEvent *)event).interval];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.backwardToken = [centre.skipBackwardCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            [weakSelf skipBy:-((MPSkipIntervalCommandEvent *)event).interval];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
}

- (MPRemoteCommandHandlerStatus)remotePlay:(__unused MPRemoteCommandEvent *)event {
    [self.player play];
    [self showPlaying:YES];
    [self describeToLockScreen];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remotePause:(__unused MPRemoteCommandEvent *)event {
    [self.player pause];
    [self showPlaying:NO];
    [self describeToLockScreen];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)describeToLockScreen {
    SCIYTJob *job = [self current];
    if (!job) return;

    NSMutableDictionary *now = [NSMutableDictionary dictionary];
    now[MPMediaItemPropertyTitle] = job.title;
    now[MPMediaItemPropertyArtist] = SCILocalized(@"panel_title");
    now[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(self.player.currentTime));
    now[MPNowPlayingInfoPropertyPlaybackRate] = @(self.player.rate);
    now[MPNowPlayingInfoPropertyDefaultPlaybackRate] = @1;
    now[MPNowPlayingInfoPropertyMediaType] =
        @(job.kind == SCIYTJobKindAudio ? MPNowPlayingInfoMediaTypeAudio
                                        : MPNowPlayingInfoMediaTypeVideo);

    // Where it sits in the queue, which is what turns two arrows into something you can
    // steer by -- "3 of 12" tells you whether pressing next is worth it.
    now[MPNowPlayingInfoPropertyPlaybackQueueIndex] = @(self.index);
    now[MPNowPlayingInfoPropertyPlaybackQueueCount] = @(self.jobs.count);

    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (isfinite(length) && length > 0) now[MPMediaItemPropertyPlaybackDuration] = @(length);

    UIImage *still = [SCIYTThumbnails cached:job];
    if (still) {
        now[MPMediaItemPropertyArtwork] =
            [[MPMediaItemArtwork alloc] initWithBoundsSize:still.size
                                            requestHandler:^UIImage *(__unused CGSize size) { return still; }];
    }

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = now;
}

@end
