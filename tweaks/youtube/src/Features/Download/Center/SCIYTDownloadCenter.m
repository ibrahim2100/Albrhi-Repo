#import "SCIYTDownloadCenter.h"
#import "SCIYTLibrary.h"
#import "../../../SCILog.h"
#import "../../../Localization/SCILocalize.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

static UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}

@interface SCIYTDownloadCenter ()
@property (nonatomic, strong) NSArray<SCIYTJob *> *rows;
@end

@implementation SCIYTDownloadCenter

+ (void)present {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    // Wrapped, the way the settings panel is. A screen of ours failing to build must be
    // a screen that does not open, never a crash inside YouTube.
    @try {
        SCIYTDownloadCenter *centre = [[SCIYTDownloadCenter alloc] initWithStyle:UITableViewStyleInsetGrouped];
        UINavigationController *host = [[UINavigationController alloc] initWithRootViewController:centre];
        host.modalPresentationStyle = UIModalPresentationPageSheet;
        [top presentViewController:host animated:YES completion:nil];
    } @catch (NSException *exception) {
        SCILogV(@"centre: could not open — %@", exception.reason);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = SCILocalized(@"dl_centre_title");
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                       target:self
                                                       action:@selector(close)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:SCIYTLibraryDidChangeNotification
                                               object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)reload {
    self.rows = [SCIYTLibrary shared].jobs;
    [self.tableView reloadData];
}

// MARK: - The list

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)MAX(self.rows.count, (NSUInteger)1);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (!self.rows.count) return nil;

    NSString *size = [NSByteCountFormatter stringFromByteCount:[[SCIYTLibrary shared] totalBytes]
                                                    countStyle:NSByteCountFormatterCountStyleFile];
    return [NSString stringWithFormat:SCILocalized(@"dl_centre_footer"),
            (unsigned long)self.rows.count, size];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];

    if (!self.rows.count) {
        cell.textLabel.text = SCILocalized(@"dl_centre_empty");
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.text = SCILocalized(@"dl_centre_empty_hint");
        cell.detailTextLabel.numberOfLines = 0;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];

    cell.textLabel.text = job.title;
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [job statusLine];
    cell.detailTextLabel.textColor = (job.state == SCIYTJobStateFailed)
        ? [UIColor systemRedColor] : [UIColor secondaryLabelColor];

    NSString *symbol = (job.kind == SCIYTJobKindAudio) ? @"music.note" : @"film";
    if (job.state == SCIYTJobStateWorking) symbol = @"arrow.down.circle";
    if (job.state == SCIYTJobStateFailed) symbol = @"exclamationmark.triangle";

    cell.imageView.image = [UIImage systemImageNamed:symbol];
    cell.imageView.tintColor = (job.state == SCIYTJobStateFailed) ? [UIColor systemRedColor] : SCIAccent();

    if (job.state == SCIYTJobStateWorking) {
        // The bar lives in the row, which is the whole reason downloading no longer
        // stops the app: this can be scrolled past, backgrounded, or ignored.
        UIProgressView *bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        bar.progressTintColor = SCIAccent();
        bar.progress = (float)job.progress;
        bar.frame = CGRectMake(0, 0, 60, 2);
        cell.accessoryView = bar;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (job.state == SCIYTJobStateDone) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.rows.count) return;

    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];
    if (job.state != SCIYTJobStateDone) return;

    [self play:job];
}

// MARK: - Playing one here

- (void)play:(SCIYTJob *)job {
    NSURL *file = [job fileURL];
    if (!file) {
        [[SCIYTLibrary shared] remove:job];
        return;
    }

    // The category is set because YouTube's own is not ours to assume: a player opened
    // while the app is muted, or over a video that was playing, needs to be told that it
    // is the one making sound now.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    AVPlayerViewController *player = [[AVPlayerViewController alloc] init];
    player.player = [AVPlayer playerWithURL:file];

    [self presentViewController:player animated:YES completion:^{
        [player.player play];
    }];
}

// MARK: - What can be done to a row

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (!self.rows.count) return nil;
    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];

    UIContextualAction *remove =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:SCILocalized(@"delete")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [[SCIYTLibrary shared] remove:job];
        done(YES);
    }];

    if (job.state != SCIYTJobStateDone) return [UISwipeActionsConfiguration configurationWithActions:@[remove]];

    UIContextualAction *share =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:SCILocalized(@"dl_share")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [self share:job from:source];
        done(YES);
    }];
    share.backgroundColor = [UIColor systemBlueColor];

    UIContextualAction *photos =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:SCILocalized(@"dl_to_photos")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [[SCIYTLibrary shared] export:job completion:^(BOOL ok, NSString *detail) {
            [self say:ok ? SCILocalized(@"dl_saved") : (detail ?: SCILocalized(@"dl_failed"))];
        }];
        done(YES);
    }];
    photos.backgroundColor = SCIAccent();

    return [UISwipeActionsConfiguration configurationWithActions:@[remove, photos, share]];
}

- (void)share:(SCIYTJob *)job from:(UIView *)source {
    NSURL *file = [job fileURL];
    if (!file) return;

    UIActivityViewController *sheet =
        [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];

    // An unanchored sheet is fatal on iPad, every time, and this one is opened from a
    // swipe action whose view is the only sensible anchor.
    sheet.popoverPresentationController.sourceView = source ?: self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX((source ?: self.view).bounds),
                   CGRectGetMidY((source ?: self.view).bounds), 1, 1);

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)say:(NSString *)message {
    if (!message.length) return;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_title")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
