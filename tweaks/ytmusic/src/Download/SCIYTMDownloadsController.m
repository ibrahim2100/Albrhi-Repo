#import "SCIYTMDownloadsController.h"
#import "SCIYTMLibrary.h"
#import "SCIYTMDownload.h"
#import "../Localization/SCILocalize.h"

@interface SCIYTMDownloadsController ()
@property (nonatomic, strong) NSArray<SCIYTMTrack *> *tracks;
@property (nonatomic, strong) UITableView *tableView;

/// The screen's own heading: what this page is, and how much is in it. A navigation bar would
/// have been the ordinary answer and there is none here -- the page is a child inside the app's
/// own browse controller, which has its own chrome and no title to lend us.
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UILabel *headerCount;

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
    self = [super initWithNibName:nil bundle:nil];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self buildHeader];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                  style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

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
    [self refreshHeader];
    [self.tableView reloadData];
    [self.view setNeedsLayout];
}

#pragma mark - The heading

- (void)buildHeader {
    self.header = [[UIView alloc] init];
    [self.view addSubview:self.header];

    UIImageView *mark = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"arrow.down.circle.fill"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30
                                                                                  weight:UIImageSymbolWeightSemibold]]];
    mark.tintColor = SCIYTMBarAccent();
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [mark.widthAnchor constraintEqualToConstant:34].active = YES;
    [mark.heightAnchor constraintEqualToConstant:34].active = YES;

    UILabel *title = [[UILabel alloc] init];
    title.text = SCILocalized(@"downloads_title");
    title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];

    self.headerCount = [[UILabel alloc] init];
    self.headerCount.font = [UIFont systemFontOfSize:13];
    self.headerCount.textColor = [UIColor secondaryLabelColor];

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.headerCount]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 1;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[mark, text]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:self.header.trailingAnchor constant:-20],
        [row.centerYAnchor constraintEqualToAnchor:self.header.centerYAnchor],
    ]];
}

/// The count and the size on disk, refreshed with the list.
///
/// Bytes rather than a track count alone: *how much of my phone is this* is the question a
/// downloads screen is actually asked, and it is the one the Files app cannot answer for a folder
/// buried three levels down.
- (void)refreshHeader {
    unsigned long long total = 0;
    for (SCIYTMTrack *track in self.tracks) total += track.bytes;

    NSString *size = [NSByteCountFormatter stringFromByteCount:(long long)total
                                                     countStyle:NSByteCountFormatterCountStyleFile];
    self.headerCount.text = self.tracks.count
        ? [NSString stringWithFormat:@"%lu · %@", (unsigned long)self.tracks.count, size]
        : SCILocalized(@"downloads_empty");
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


/// The height of one view of a named class, wherever it sits in the window.
///
/// Measured rather than written down: these heights belong to YouTube Music, differ by device, and
/// change as the player docks. A view that is not there, or is hidden, contributes nothing -- which
/// costs a little space and never buries a control under the app's own.
static CGFloat SCIYTMHeightOfClass(UIWindow *window, NSString *className) {
    Class target = NSClassFromString(className);
    if (!window || !target) return 0;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([view isKindOfClass:target] && !view.hidden && view.alpha > 0.01) {
            return view.bounds.size.height;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return 0;
}

/// Where the app's own top bar ends, in window coordinates.
///
/// **The header went under the YouTube Music logo, and the safe area was never going to say so.**
/// The safe area describes the *device* -- the notch, the clock, the home indicator -- and knows
/// nothing about a bar the app drew itself. YouTube Music keeps its logo and search in a header of
/// its own, directly below the status bar, and content that merely clears the safe area is content
/// underneath it.
///
/// Found by shape rather than by one class name: any visible view whose class reads as a header or
/// a navigation bar, sitting in the top third of the window, and wide enough to be chrome rather
/// than a control inside it. A build that renames its header keeps working; a build with no header
/// contributes nothing and the safe area alone decides.
static CGFloat SCIYTMTopChromeBottom(UIWindow *window) {
    if (!window) return 0;

    CGFloat lowest = 0;
    CGFloat limit = CGRectGetHeight(window.bounds) / 3;

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if (view.hidden || view.alpha < 0.01) continue;

        NSString *name = NSStringFromClass([view class]);
        BOOL looksLikeChrome = [name containsString:@"FlexibleHeader"] ||
                               [name containsString:@"NavigationBar"] ||
                               [name isEqualToString:@"YTMSearchBarView"];

        if (looksLikeChrome) {
            CGRect inWindow = [view convertRect:view.bounds toView:window];
            BOOL nearTop = CGRectGetMinY(inWindow) < limit;
            BOOL wideEnough = CGRectGetWidth(inWindow) > CGRectGetWidth(window.bounds) * 0.6;

            if (nearTop && wideEnough) lowest = MAX(lowest, CGRectGetMaxY(inWindow));
            continue;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return lowest;
}

/// The app's own mini player, when one of its tracks is docked above the tab bar.
///
/// **This is why our transport ended up underneath it.** The bar was placed above the tab bar and
/// nothing else, and YouTube Music parks its own player in exactly that space the moment it is
/// playing something.
static CGFloat SCIYTMMiniPlayerHeight(UIWindow *window) {
    return SCIYTMHeightOfClass(window, @"YTMMiniPlayerView");
}

/// How much of the bottom the app's own tab bar is occupying.
///
/// **Measured off the bar itself rather than written down.** Its height is a number that belongs
/// to YouTube Music, changes with the device and changes again when the player docks above it, and
/// a constant here would be right on one phone. A bar that cannot be found returns zero, which
/// costs a little space at the bottom and never hides a row behind something.
static CGFloat SCIYTMBottomBarHeight(UIWindow *window) {
    return SCIYTMHeightOfClass(window, @"YTPivotBarView");
}

/// Kept in step on every layout pass, not set once.
///
/// The safe area moves: a call banner appears, the device rotates, the player docks over the
/// bottom. Anything read once at load is the value the screen had before any of that.
/// The real safe area, taken as the largest any window reports.
///
/// **`isKeyWindow` is not a reliable way to find the screen.** A keyboard window, a text-effects
/// window or any overlay can be key at the moment this runs, and those report insets of zero --
/// which is a top inset of nothing on a notched phone, and a list that starts under the clock.
/// Five earlier fixes were each undone by something; this one was measuring the wrong window.
///
/// The largest is the right answer rather than a guess: an overlay never reports *more* than the
/// screen it sits on, so the maximum is the screen's own.
static UIEdgeInsets SCIYTMScreenSafeArea(void) {
    UIEdgeInsets widest = UIEdgeInsetsZero;

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        UIEdgeInsets insets = window.safeAreaInsets;
        widest.top = MAX(widest.top, insets.top);
        widest.bottom = MAX(widest.bottom, insets.bottom);
        widest.left = MAX(widest.left, insets.left);
        widest.right = MAX(widest.right, insets.right);
    }
    return widest;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIWindow *window = self.view.window;
    if (!window) {
        for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
    }

    UIEdgeInsets safe = SCIYTMScreenSafeArea();
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);

    // **How far down this view already sits.** If the parent has already placed us below the
    // status bar, adding the safe area again would push the list down twice -- the opposite
    // mistake, and just as visible. Asked of the window rather than assumed either way.
    CGFloat originInWindow = [self.view convertPoint:CGPointZero toView:nil].y;

    // Below the device's own furniture *and* the app's. Whichever ends lower is the one that
    // matters, and on this app it is the header with the logo in it.
    CGFloat clearsTo = MAX(safe.top, SCIYTMTopChromeBottom(window));
    CGFloat top = MAX(0, clearsTo - originInWindow);

    // What the app has parked at the bottom: its tab bar, and its own mini player above it when
    // something of YouTube Music's is playing. Both measured off the views themselves.
    CGFloat chrome = MAX(safe.bottom,
                         SCIYTMBottomBarHeight(window) + SCIYTMMiniPlayerHeight(window));

    CGFloat transportHeight = self.playerBar.hidden ? 0 : 52;
    CGFloat transportGap = self.playerBar.hidden ? 0 : 8;

    self.playerBar.frame = CGRectMake(12,
                                      height - chrome - transportGap - transportHeight,
                                      width - 24, transportHeight);

    self.header.frame = CGRectMake(0, top, width, self.header.hidden ? 0 : 74);
    CGFloat listTop = top + (self.header.hidden ? 0 : 74);

    self.tableView.frame = CGRectMake(0, listTop, width,
                                      height - listTop - chrome - transportGap - transportHeight);
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
