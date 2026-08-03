#import "SCIYTPlayer.h"
#import "SCIYTThumbnails.h"
#import "../../../SCILog.h"
#import "../../../Localization/SCILocalize.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

@interface SCIYTPlayer ()
@property (nonatomic, strong) NSArray<SCIYTJob *> *jobs;
@property (nonatomic) NSUInteger index;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *layer;
@property (nonatomic, strong) id ticker;

@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *elapsed;
@property (nonatomic, strong) UILabel *remaining;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UIButton *playPause;
@property (nonatomic) BOOL scrubbing;

/// What -addTargetWithHandler: gave back.
///
/// A block target has no target to name later, so the only way to take it off again is the
/// token it returned. Without these two the next and previous handlers stay on the shared
/// command centre for the life of the app.
@property (nonatomic, strong) id nextToken;
@property (nonatomic, strong) id previousToken;
@property (nonatomic, strong) id positionToken;
@property (nonatomic, strong) id forwardToken;
@property (nonatomic, strong) id backwardToken;
@property (nonatomic) BOOL torndown;

/// Whether the lock screen has been told how long this one runs.
///
/// It cannot be told at the moment playback starts, which is when everything else is
/// published: a player item that has only just been handed a file answers "indefinite"
/// until it has read the header. A duration of indefinite is not a shorter bar, it is no
/// bar at all -- which is why the lock screen showed a title and no counter.
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

// MARK: - Building it

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // Playback, and active. Without this a saved video plays through the silent switch
    // the way a notification does, and stops the moment the phone locks.
    NSError *audioError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioError];
    [[AVAudioSession sharedInstance] setActive:YES error:&audioError];
    if (audioError) SCILogV(@"player: audio session — %@", audioError.localizedDescription);

    [self buildStage];
    [self buildControls];
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

    // Teardown happens here and not in -dealloc, because -dealloc cannot be reached.
    //
    // MPRemoteCommandCenter is one object for the whole process and it holds its targets
    // strongly, so registering with it makes this controller immortal: closing the player
    // released the last reference anyone else held and the command centre kept it anyway.
    // Everything -dealloc was written to undo was therefore never undone. The player went
    // on existing with its file open and its observers live, and the lock screen's next
    // button still reached it -- so opening the Centre a second time left two players
    // listening and one tap skipped two tracks.
    //
    // Being covered by another screen is not leaving, so only a real dismissal counts.
    if (self.isBeingDismissed || self.movingFromParentViewController) [self teardown];
}

- (void)dealloc {
    [self teardown];
}

- (void)teardown {
    if (self.torndown) return;
    self.torndown = YES;

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (self.ticker) {
        [self.player removeTimeObserver:self.ticker];
        self.ticker = nil;
    }

    [self.player pause];
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

    // Handed back so whatever was playing before -- YouTube itself, usually -- is allowed
    // to resume. Left active, this tweak keeps the audio route after its own player is gone.
    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
}

/// Where the picture goes, or the artwork when there is no picture.
- (void)buildStage {
    self.stage = [[UIView alloc] init];
    self.stage.backgroundColor = [UIColor blackColor];
    self.stage.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stage];

    self.artwork = [[UIImageView alloc] init];
    self.artwork.contentMode = UIViewContentModeScaleAspectFit;
    self.artwork.tintColor = SCIAccent();
    self.artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self.stage addSubview:self.artwork];

    [NSLayoutConstraint activateConstraints:@[
        [self.stage.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.stage.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.stage.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.artwork.centerXAnchor constraintEqualToAnchor:self.stage.centerXAnchor],
        [self.artwork.centerYAnchor constraintEqualToAnchor:self.stage.centerYAnchor],
        [self.artwork.widthAnchor constraintEqualToAnchor:self.stage.widthAnchor multiplier:0.7],
        [self.artwork.heightAnchor constraintEqualToAnchor:self.artwork.widthAnchor]
    ]];

    self.layer = [AVPlayerLayer layer];
    self.layer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.stage.layer addSublayer:self.layer];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // The one layer here that has no constraints, because a CALayer has none. It is set
    // from the view that owns it and from nothing else.
    self.layer.frame = self.stage.bounds;
}

/// The controls, in one stack.
///
/// A stack view rather than a row of siblings pinned to each other: the panel this project
/// rebuilt three times died in CoreAutoLayout, and the lesson was that a container which
/// spaces its own children cannot be given an unsatisfiable set of constraints.
- (void)buildControls {
    self.name = [[UILabel alloc] init];
    self.name.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.name.textColor = [UIColor whiteColor];
    self.name.textAlignment = NSTextAlignmentCenter;
    self.name.numberOfLines = 2;

    self.scrubber = [[UISlider alloc] init];
    self.scrubber.minimumTrackTintColor = SCIAccent();
    self.scrubber.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.25];
    [self.scrubber addTarget:self action:@selector(scrubStarted)
            forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubEnded)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];

    self.elapsed = [self timeLabel:NSTextAlignmentLeft];
    self.remaining = [self timeLabel:NSTextAlignmentRight];

    UIStackView *times = [[UIStackView alloc] initWithArrangedSubviews:@[self.elapsed, self.remaining]];
    times.axis = UILayoutConstraintAxisHorizontal;
    times.distribution = UIStackViewDistributionFillEqually;

    UIButton *previous = [self control:@"backward.end.fill" size:26 action:@selector(previous)];
    self.playPause = [self control:@"pause.fill" size:40 action:@selector(togglePlay)];
    UIButton *next = [self control:@"forward.end.fill" size:26 action:@selector(next)];

    UIStackView *transport =
        [[UIStackView alloc] initWithArrangedSubviews:@[previous, self.playPause, next]];
    transport.axis = UILayoutConstraintAxisHorizontal;
    transport.distribution = UIStackViewDistributionFillEqually;
    transport.alignment = UIStackViewAlignmentCenter;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[self.name, self.scrubber, times, transport]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UIButton *close = [self control:@"xmark.circle.fill" size:28 action:@selector(close)];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:close];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-24],
        [self.stage.bottomAnchor constraintEqualToAnchor:stack.topAnchor constant:-16],

        [close.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [close.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [close.widthAnchor constraintEqualToConstant:40],
        [close.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (UILabel *)timeLabel:(NSTextAlignment)alignment {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    label.textColor = [UIColor colorWithWhite:1 alpha:0.6];
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

// MARK: - The queue

- (SCIYTJob *)current {
    return (self.index < self.jobs.count) ? self.jobs[self.index] : nil;
}

- (void)load {
    SCIYTJob *job = [self current];
    NSURL *file = [job fileURL];

    // A row whose file went missing is skipped rather than played as silence. It can
    // happen: the folder is open to the Files app on purpose.
    if (!file) {
        if (self.index + 1 < self.jobs.count) { self.index++; [self load]; return; }
        [self close];
        return;
    }

    if (self.ticker) { [self.player removeTimeObserver:self.ticker]; self.ticker = nil; }

    self.player = [AVPlayer playerWithURL:file];

    // Watched on *this* item, and re-registered for each one.
    //
    // Observing the notification with a nil object is the obvious way to write it and it
    // is wrong inside another app: the notification is posted for every item that ends
    // anywhere in the process, so a YouTube video finishing in the background would skip
    // our queue forward. The item is the object; nothing else may speak for it.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachedEnd)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];
    self.layer.player = (job.kind == SCIYTJobKindVideo) ? self.player : nil;

    UIImage *still = [SCIYTThumbnails cached:job];
    self.artwork.image = still ?: [UIImage systemImageNamed:@"music.note"];
    self.artwork.hidden = (job.kind == SCIYTJobKindVideo);

    self.name.text = job.title;
    self.scrubber.value = 0;
    self.publishedLength = NO;   // the next one's length is not this one's

    __weak __typeof(self) weakSelf = self;
    self.ticker = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                             queue:dispatch_get_main_queue()
                                                        usingBlock:^(CMTime time) {
        [weakSelf tick];
    }];

    [self.player play];
    [self showPlaying:YES];
    [self describeToLockScreen];
}

- (void)next {
    if (self.index + 1 >= self.jobs.count) { [self.player pause]; [self showPlaying:NO]; return; }
    self.index++;
    [self load];
}

- (void)previous {
    // Back to the start first, then to the previous one -- which is what every player
    // does and what the button is reached for nine times out of ten.
    if (CMTimeGetSeconds(self.player.currentTime) > 3 || self.index == 0) {
        [self.player seekToTime:kCMTimeZero];
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
}

- (void)showPlaying:(BOOL)playing {
    UIImageSymbolConfiguration *weight =
        [UIImageSymbolConfiguration configurationWithPointSize:40 weight:UIImageSymbolWeightMedium];
    [self.playPause setImage:[UIImage systemImageNamed:(playing ? @"pause.fill" : @"play.fill")
                                     withConfiguration:weight]
                    forState:UIControlStateNormal];
}

- (void)close {
    [self.player pause];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - The scrubber

- (void)scrubStarted { self.scrubbing = YES; }

- (void)scrubEnded {
    self.scrubbing = NO;

    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(length) || length <= 0) return;

    [self seekTo:self.scrubber.value * length];
}

/// Moves to a point, and tells the lock screen where it now is.
///
/// Both remote seeks come through here rather than calling -seekToTime: themselves: the
/// now-playing entry has to be rewritten after a jump or the counter carries on from where
/// it was, and one place to forget that is better than three.
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

    // The length arrives late, and the lock screen was told everything else before it did.
    // Publishing once here is what turns a bare title into a counter with a scrubber.
    if (!self.publishedLength) {
        self.publishedLength = YES;
        [self describeToLockScreen];
    }

    if (self.scrubbing) return;

    self.scrubber.value = (float)(at / length);
    self.elapsed.text = [SCIYTThumbnails clock:at];
    self.remaining.text = [@"-" stringByAppendingString:[SCIYTThumbnails clock:length - at]];
}

// MARK: - Off the screen

/// The layer is emptied, not the player.
///
/// iOS stops playback through a layer that is not being drawn, so a video would fall
/// silent the moment the phone locked -- which is exactly the thing someone saving a
/// video to listen to does not want. Handing the layer back on return puts the picture
/// where the sound already is.
- (void)wentAway {
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
    centre.nextTrackCommand.enabled = YES;
    centre.previousTrackCommand.enabled = YES;

    // The three that make the counter a control rather than a readout.
    //
    // A now-playing entry with a duration draws a scrubber, but dragging it does nothing
    // unless this command is claimed -- iOS asks whoever is playing to move, and with no
    // one listening the thumb springs back. The skip pair is what the lock screen offers
    // instead of next/previous when both are claimed, so both are.
    centre.changePlaybackPositionCommand.enabled = YES;
    centre.skipForwardCommand.enabled = YES;
    centre.skipBackwardCommand.enabled = YES;
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

    self.forwardToken = [centre.skipForwardCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            MPSkipIntervalCommandEvent *skip = (MPSkipIntervalCommandEvent *)event;
            [weakSelf skipBy:skip.interval];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.backwardToken = [centre.skipBackwardCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            MPSkipIntervalCommandEvent *skip = (MPSkipIntervalCommandEvent *)event;
            [weakSelf skipBy:-skip.interval];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.nextToken = [centre.nextTrackCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            [weakSelf next];
            return MPRemoteCommandHandlerStatusSuccess;
        }];

    self.previousToken = [centre.previousTrackCommand
        addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            [weakSelf previous];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
}

- (MPRemoteCommandHandlerStatus)remotePlay:(MPRemoteCommandEvent *)event {
    [self.player play];
    [self showPlaying:YES];
    [self describeToLockScreen];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remotePause:(MPRemoteCommandEvent *)event {
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

    // The rate is what makes the counter count. iOS does not poll: it takes the elapsed
    // time once and moves it forward at whatever rate was declared, so a paused entry that
    // claims rate 1 keeps counting and a playing one that omits it stands still.
    now[MPNowPlayingInfoPropertyPlaybackRate] = @(self.player.rate);
    now[MPNowPlayingInfoPropertyDefaultPlaybackRate] = @1;
    now[MPNowPlayingInfoPropertyMediaType] =
        @(job.kind == SCIYTJobKindAudio ? MPNowPlayingInfoMediaTypeAudio
                                        : MPNowPlayingInfoMediaTypeVideo);

    double length = CMTimeGetSeconds(self.player.currentItem.duration);
    if (isfinite(length) && length > 0) now[MPMediaItemPropertyPlaybackDuration] = @(length);

    UIImage *still = [SCIYTThumbnails cached:job];
    if (still) {
        now[MPMediaItemPropertyArtwork] =
            [[MPMediaItemArtwork alloc] initWithBoundsSize:still.size
                                            requestHandler:^UIImage *(CGSize size) { return still; }];
    }

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = now;
}

@end
