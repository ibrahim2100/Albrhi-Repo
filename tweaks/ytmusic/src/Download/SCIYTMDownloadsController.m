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
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Read on every appearance rather than cached: a track saved while this screen was pushed away,
    // or deleted from the Files app, must be right when it comes back. Listing a folder is cheap
    // enough that a cache would only be a way to be wrong.
    self.tracks = SCIYTMSavedTracks();
    [self.tableView reloadData];
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
