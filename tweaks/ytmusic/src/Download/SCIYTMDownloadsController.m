#import "SCIYTMDownloadsController.h"
#import "SCIYTMLibrary.h"
#import "SCIYTMDownload.h"
#import "../Localization/SCILocalize.h"

@interface SCIYTMDownloadsController ()
@property (nonatomic, strong) NSArray<SCIYTMTrack *> *tracks;

/// The transport, drawn by us because the app's belongs to the app's player.
///
/// **This is the whole of "I cannot pause or skip".** A file of ours plays through our own
/// `AVPlayer`; YouTube Music's play button, its scrubber and its next button all speak to its
/// own player and always did. Nothing was fighting -- there was simply no control anywhere
/// that addressed the thing making the sound. Now there is, on the screen the track was
/// started from.
@property (nonatomic, strong) UIView *playerBar;
@property (nonatomic, strong) UILabel *playingLabel;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) NSTimer *ticker;
@property (nonatomic, assign) BOOL scrubbing;
@end

@implementation SCIYTMDownloadsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self buildPlayerBar];
    self.title = SCILocalized(@"downloads_title");
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;

    //
    // **The page was starting at the very top of the app and ending behind the tab bar.**
    //
    // It is added as a child filling the parent's bounds, which is right -- the background
    // should cover the whole screen -- but the *list* has to keep clear of the status bar
    // above and the pivot bar below. Those insets are not a number worth writing down: the
    // app publishes them, through the safe area it hands its own children, and it moves them
    // when a bar appears or the player docks.
    //
    // `Always` rather than `Automatic`: automatic only adjusts a scroll view the system
    // believes is the controller's primary one, and this table belongs to a child controller
    // somebody else installed -- exactly the case where it declines and the content starts
    // under the clock.
    //
    //
    // **Measured from the window, because the parent's safe area is not to be trusted here.**
    //
    // `Always` was tried first and the first row still went under the clock: the adjustment is
    // computed from *this view's* safe area, and a parent that has already consumed its own --
    // which a controller hosting its content inside its own chrome does -- hands its children
    // an inset of zero. The window is the one view that always knows where the status bar and
    // the home indicator are, so the inset is taken from there and applied by hand.
    //
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Read on every appearance rather than cached: a track saved while this screen was pushed away,
    // or deleted from the Files app, must be right when it comes back. Listing a folder is cheap
    // enough that a cache would only be a way to be wrong.
    self.tracks = SCIYTMSavedTracks();
    [self.tableView reloadData];
}

#pragma mark - The transport

static UIColor *SCIYTMBarAccent(void) {
    return [UIColor colorWithRed:230/255.0 green:75/255.0 blue:75/255.0 alpha:1];
}

static NSString *SCIYTMClock(double seconds) {
    if (!isfinite(seconds) || seconds < 0) seconds = 0;
    int whole = (int)seconds;
    return [NSString stringWithFormat:@"%d:%02d", whole / 60, whole % 60];
}

- (UIButton *)transportButton:(NSString *)symbol action:(SEL)action big:(BOOL)big {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:(big ? 28 : 20)
                                                        weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:config]
            forState:UIControlStateNormal];
    button.tintColor = big ? SCIYTMBarAccent() : [UIColor labelColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildPlayerBar {
    self.playerBar = [[UIView alloc] init];
    self.playerBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.playerBar.layer.cornerRadius = 18;
    self.playerBar.layer.cornerCurve = kCACornerCurveContinuous;
    self.playerBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.playerBar.hidden = YES;

    // On the view above the table rather than in it. A footer scrolls away, and a transport
    // that scrolls away is a transport somebody has to go looking for.
    [self.view addSubview:self.playerBar];

    self.playingLabel = [[UILabel alloc] init];
    self.playingLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.playingLabel.textColor = [UIColor labelColor];
    self.playingLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.elapsedLabel = [[UILabel alloc] init];
    self.elapsedLabel.font = [UIFont monospacedDigitSystemFontOfSize:12
                                                              weight:UIFontWeightRegular];
    self.elapsedLabel.textColor = [UIColor secondaryLabelColor];

    self.scrubber = [[UISlider alloc] init];
    self.scrubber.minimumTrackTintColor = SCIYTMBarAccent();
    [self.scrubber addTarget:self action:@selector(scrubBegan)
            forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubEnded)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];

    UIButton *previous = [self transportButton:@"backward.fill" action:@selector(previousTapped) big:NO];
    self.playButton = [self transportButton:@"pause.circle.fill" action:@selector(playTapped) big:YES];
    UIButton *next = [self transportButton:@"forward.fill" action:@selector(nextTapped) big:NO];

    UIStackView *controls = [[UIStackView alloc] initWithArrangedSubviews:@[previous, self.playButton, next]];
    controls.axis = UILayoutConstraintAxisHorizontal;
    controls.alignment = UIStackViewAlignmentCenter;
    controls.spacing = 18;

    UIStackView *middle = [[UIStackView alloc] initWithArrangedSubviews:@[self.playingLabel, self.scrubber]];
    middle.axis = UILayoutConstraintAxisVertical;
    middle.spacing = 0;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[middle, self.elapsedLabel, controls]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 10;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playerBar addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:self.playerBar.topAnchor constant:8],
        [row.bottomAnchor constraintEqualToAnchor:self.playerBar.bottomAnchor constant:-8],
        [row.leadingAnchor constraintEqualToAnchor:self.playerBar.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:self.playerBar.trailingAnchor constant:-14],
        [controls.widthAnchor constraintEqualToConstant:120],
    ]];

    // A tick rather than a periodic time observer: the observer belongs to the player and this
    // screen can be closed while the track keeps going, which would leave an observer holding a
    // controller nobody can see. A timer invalidated on disappear cannot.
    self.ticker = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        [self refreshTransport];
    }];
}

- (void)refreshTransport {
    SCIYTMTrack *track = SCIYTMCurrentTrack();
    self.playerBar.hidden = (track == nil);
    if (!track) return;

    self.playingLabel.text = track.title;

    NSString *pauseOrPlay = SCIYTMIsPlaying() ? @"pause.circle.fill" : @"play.circle.fill";
    [self.playButton setImage:
        [UIImage systemImageNamed:pauseOrPlay
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28
                                                                                  weight:UIImageSymbolWeightSemibold]]
                     forState:UIControlStateNormal];

    double elapsed = 0, duration = 0;
    SCIYTMProgress(&elapsed, &duration);
    self.elapsedLabel.text = [NSString stringWithFormat:@"%@ / %@",
                              SCIYTMClock(elapsed), SCIYTMClock(duration)];

    // Not while a finger is on it: a slider that is being dragged and written to at the same
    // time fights the person holding it.
    if (!self.scrubbing && duration > 0) {
        self.scrubber.maximumValue = (float)duration;
        self.scrubber.value = (float)elapsed;
    }
}

- (void)scrubBegan { self.scrubbing = YES; }

- (void)scrubEnded {
    self.scrubbing = NO;
    SCIYTMSeekTo(self.scrubber.value);
}

- (void)playTapped { SCIYTMTogglePlayPause(); [self refreshTransport]; }
- (void)nextTapped { SCIYTMNext(); [self refreshTransport]; }
- (void)previousTapped { SCIYTMPrevious(); [self refreshTransport]; }

- (void)dealloc {
    [self.ticker invalidate];
}


/// How much of the bottom the app's own tab bar is occupying.
///
/// **Measured off the bar itself rather than written down.** Its height is a number that belongs
/// to YouTube Music, changes with the device and changes again when the player docks above it, and
/// a constant here would be right on one phone. A bar that cannot be found returns zero, which
/// costs a little space at the bottom and never hides a row behind something.
static CGFloat SCIYTMBottomBarHeight(UIWindow *window) {
    Class barClass = NSClassFromString(@"YTPivotBarView");
    if (!window || !barClass) return 0;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([view isKindOfClass:barClass] && !view.hidden && view.alpha > 0.01) {
            return view.bounds.size.height;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return 0;
}

/// Kept in step on every layout pass, not set once.
///
/// The safe area moves: a call banner appears, the device rotates, the player docks over the
/// bottom. Anything read once at load is the value the screen had before any of that.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // The key window when this view has none of its own: a child added to a parent that is
    // itself off screen for a moment reports no window, and reading zero from that is how an
    // inset comes out right on the second layout pass and wrong on the first -- which is the
    // one that decides where the list appears.
    UIWindow *window = self.view.window;
    if (!window) {
        for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
    }

    UIEdgeInsets safe = window.safeAreaInsets;

    // The pivot bar sits above the home indicator and is the app's own chrome rather than a
    // system inset, so its height is asked of the app: whatever the window reports below the
    // safe area is what the bar and the docked player occupy together.
    CGFloat bar = SCIYTMBottomBarHeight(window);
    CGFloat bottom = MAX(safe.bottom, bar);

    // The transport sits above the app's own bar, and the list keeps clear of both.
    CGFloat transport = self.playerBar.hidden ? 0 : 64;

    self.playerBar.frame = CGRectMake(12,
                                      CGRectGetHeight(self.view.bounds) - bottom - 60,
                                      CGRectGetWidth(self.view.bounds) - 24, 52);

    UIEdgeInsets wanted = UIEdgeInsetsMake(safe.top, 0, bottom + transport, 0);

    BOOL wasAtTop = self.tableView.contentOffset.y <= -self.tableView.contentInset.top + 0.5;

    if (!UIEdgeInsetsEqualToEdgeInsets(self.tableView.contentInset, wanted)) {
        self.tableView.contentInset = wanted;
        self.tableView.verticalScrollIndicatorInsets = wanted;
    }

    //
    // **Setting an inset does not move what is already there, and that is the whole of the
    // bug this line fixes.**
    //
    // A scroll view keeps its `contentOffset` when its inset changes, so an offset of zero --
    // which is where a freshly loaded list sits -- stops meaning "the top" the moment a top
    // inset exists and starts meaning "scrolled up by exactly that much". The first row goes
    // under the clock, which is precisely what was reported after the inset itself was
    // already correct.
    //
    // Only when the list was at its top: somebody who has scrolled down keeps their place.
    //
    //
    // **Checked on every pass, not only when the inset changes.**
    //
    // The previous version returned early once the inset already matched -- and a
    // `-reloadData` puts the offset back to zero while leaving the inset alone, so the list
    // slid back under the clock every time it was refreshed and the one line that would have
    // fixed it had been skipped. Three attempts at this bug were each a different cause, and
    // this was the fourth: a correct value, correctly applied, and then quietly undone.
    //
    // An offset of exactly zero with a top inset present is never a place a person scrolled
    // to; it is the value a fresh or reloaded table starts at.
    //
    if (wasAtTop || fabs(self.tableView.contentOffset.y) < 0.5) {
        self.tableView.contentOffset = CGPointMake(0, -wanted.top);
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tracks.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    if (!self.tracks.count) {
        cell.textLabel.text = SCILocalized(@"downloads_empty");

        // **The empty state is where the diagnosis belongs.** Somebody reading this row is somebody
        // whose download did not happen, and the one fact that explains it is what the button they
        // pressed is called on their build.
        NSString *state = SCIYTMDownloadReport();
        NSArray<NSString *> *keys = SCIYTMSeenKeys();
        cell.detailTextLabel.text = keys.count
            ? [NSString stringWithFormat:@"%@\n\n%@", [SCILocalized(@"downloads_empty_note") stringByAppendingFormat:@"\n\n%@", state],
                [NSString stringWithFormat:SCILocalized(@"downloads_keys"),
                    [keys componentsJoinedByString:@", "]]]
            : [SCILocalized(@"downloads_empty_note") stringByAppendingFormat:@"\n\n%@", state];
        cell.detailTextLabel.numberOfLines = 0;
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    SCIYTMTrack *track = self.tracks[indexPath.row];
    BOOL playing = [SCIYTMNowPlayingURL() isEqual:track.url];

    cell.textLabel.text = track.title;
    cell.textLabel.font = [UIFont systemFontOfSize:16
                                            weight:playing ? UIFontWeightBold : UIFontWeightRegular];

    NSByteCountFormatter *size = [[NSByteCountFormatter alloc] init];
    size.countStyle = NSByteCountFormatterCountStyleFile;

    cell.detailTextLabel.text = track.artist.length
        ? [NSString stringWithFormat:@"%@ · %@", track.artist, [size stringFromByteCount:(long long)track.bytes]]
        : [size stringFromByteCount:(long long)track.bytes];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    cell.imageView.image = [UIImage systemImageNamed:playing ? @"speaker.wave.2.fill" : @"music.note"];
    cell.imageView.tintColor = playing ? [UIColor systemRedColor] : [UIColor secondaryLabelColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.tracks.count) return;

    // The whole list is the queue, starting here -- which is what a downloads screen is for, and it
    // is what makes the Lock Screen's next and previous do something.
    SCIYTMPlay(self.tracks[indexPath.row], self.tracks);
    [tableView reloadData];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (!self.tracks.count) return nil;
    SCIYTMTrack *track = self.tracks[indexPath.row];

    __weak typeof(self) weakSelf = self;

    UIContextualAction *share = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:SCILocalized(@"downloads_share")
                          handler:^(UIContextualAction *action, UIView *source, void (^done)(BOOL)) {
        UIActivityViewController *sheet =
            [[UIActivityViewController alloc] initWithActivityItems:@[track.url] applicationActivities:nil];

        sheet.popoverPresentationController.sourceView = source;
        sheet.popoverPresentationController.sourceRect = source.bounds;
        [weakSelf presentViewController:sheet animated:YES completion:nil];
        done(YES);
    }];

    UIContextualAction *remove = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:SCILocalized(@"downloads_delete")
                          handler:^(UIContextualAction *action, UIView *source, void (^done)(BOOL)) {
        // Deleting is the one irreversible thing on this screen, so it asks -- the same rule this
        // project applies to every action somebody cannot take back.
        UIAlertController *confirm =
            [UIAlertController alertControllerWithTitle:SCILocalized(@"downloads_delete_title")
                                                message:track.title
                                         preferredStyle:UIAlertControllerStyleAlert];

        [confirm addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                                    style:UIAlertActionStyleCancel
                                                  handler:^(UIAlertAction *a) { done(NO); }]];

        [confirm addAction:[UIAlertAction actionWithTitle:SCILocalized(@"downloads_delete")
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(UIAlertAction *a) {
            [[NSFileManager defaultManager] removeItemAtURL:track.url error:nil];
            weakSelf.tracks = SCIYTMSavedTracks();
            [weakSelf.tableView reloadData];
            done(YES);
        }]];

        [weakSelf presentViewController:confirm animated:YES completion:nil];
    }];

    return [UISwipeActionsConfiguration configurationWithActions:@[remove, share]];
}

@end
