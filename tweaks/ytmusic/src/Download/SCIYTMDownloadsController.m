#import "SCIYTMDownloadsController.h"
#import "SCIYTMLibrary.h"
#import "SCIYTMDownload.h"
#import "../Localization/SCILocalize.h"

@interface SCIYTMDownloadsController ()
@property (nonatomic, strong) NSArray<SCIYTMTrack *> *tracks;
@end

@implementation SCIYTMDownloadsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
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
    UIEdgeInsets wanted = UIEdgeInsetsMake(safe.top, 0, MAX(safe.bottom, bar), 0);

    if (UIEdgeInsetsEqualToEdgeInsets(self.tableView.contentInset, wanted)) return;

    CGFloat wasAtTop = self.tableView.contentOffset.y <= -self.tableView.contentInset.top + 0.5;

    self.tableView.contentInset = wanted;
    self.tableView.verticalScrollIndicatorInsets = wanted;

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
    if (wasAtTop) {
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
