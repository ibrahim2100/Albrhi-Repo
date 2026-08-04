#import "SCIYTDownloadList.h"
#import "../../../Tweak.h"
#import "SCIYTLibrary.h"
#import "SCIYTPlayer.h"
#import "SCIYTThumbnails.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"


@interface SCIYTDownloadList ()
@property (nonatomic) SCIYTJobKind kind;
@property (nonatomic, strong) NSArray<SCIYTJob *> *rows;
@end

@implementation SCIYTDownloadList

- (instancetype)initWithKind:(SCIYTJobKind)kind {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;

    _kind = kind;

    BOOL video = (kind == SCIYTJobKindVideo);
    self.title = SCILocalized(video ? @"dl_kind_video" : @"dl_kind_audio");
    self.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:self.title
                image:[UIImage systemImageNamed:video ? @"film" : @"music.note"]
                  tag:kind];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.rowHeight = (self.kind == SCIYTJobKindVideo) ? 88 : 60;

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
    NSMutableArray<SCIYTJob *> *mine = [NSMutableArray array];
    for (SCIYTJob *job in [SCIYTLibrary shared].jobs) {
        if (job.kind == self.kind) [mine addObject:job];
    }
    self.rows = mine;
    [self.tableView reloadData];

    // Stills and lengths are made after the list is on screen, never while it is being
    // drawn: opening thirty assets to fill a table is how a list arrives late.
    for (SCIYTJob *job in mine) {
        if (job.state != SCIYTJobStateDone) continue;
        [SCIYTThumbnails prepare:job completion:^(UIImage *image) {
            [self.tableView reloadData];
        }];
    }
}

// MARK: - Rows

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)MAX(self.rows.count, (NSUInteger)1);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (!self.rows.count) return nil;

    long long bytes = 0;
    for (SCIYTJob *job in self.rows) bytes += job.bytes;

    NSString *size = [NSByteCountFormatter stringFromByteCount:bytes
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
    cell.detailTextLabel.textColor = (job.state == SCIYTJobStateFailed)
        ? [UIColor systemRedColor] : [UIColor secondaryLabelColor];

    // The length goes in front of the size, because it is what someone is looking for
    // when they are choosing between two saved things.
    NSString *status = [job statusLine];
    cell.detailTextLabel.text = (job.state == SCIYTJobStateDone && job.duration > 0)
        ? [NSString stringWithFormat:@"%@ · %@", [SCIYTThumbnails clock:job.duration], status]
        : status;

    if (self.kind == SCIYTJobKindVideo) {
        UIImage *still = [SCIYTThumbnails cached:job];
        cell.imageView.image = still ?: [UIImage systemImageNamed:@"film"];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = YES;
        cell.imageView.layer.cornerRadius = 6;
        if (!still) cell.imageView.tintColor = SCIAccent();
    } else {
        // A song gets its cover, exactly as a video gets its still.
        //
        // A music-note glyph in a grey circle was what forty saved songs all looked like, and
        // a list where every row is identical is a list you have to read rather than scan.
        // The cover is already on disk -- it is fetched when the song is saved -- so this was
        // only ever a matter of asking for it.
        UIImage *cover = [SCIYTThumbnails cached:job];
        cell.imageView.image = cover ?: [UIImage systemImageNamed:@"music.note"];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = YES;

        // Rounder than a video's, because that is the shape the ear expects: album art is
        // square with soft corners, a video still is a rectangle with sharp ones, and the
        // difference tells you which list you are in without a label.
        cell.imageView.layer.cornerRadius = 10;
        cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;
        if (!cover) cell.imageView.tintColor = SCIAccent();
    }

    // What is playing right now, marked.
    //
    // The mini bar says what is playing; the list says nothing, so scrolling it while
    // something plays gives no way to find the row you are listening to. A tinted title and
    // a small mark cost nothing and answer that at a glance.
    BOOL isPlaying = [[SCIYTPlayer nowPlaying] isEqual:job];
    cell.textLabel.textColor = isPlaying ? SCIAccent() : [UIColor labelColor];
    cell.accessoryView = isPlaying ? [self playingMark] : nil;

    if (job.state == SCIYTJobStateWorking) {
        UIProgressView *bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        bar.progressTintColor = SCIAccent();
        bar.progress = (float)job.progress;
        bar.frame = CGRectMake(0, 0, 60, 2);
        cell.accessoryView = bar;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (job.state == SCIYTJobStateDone) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
        cell.imageView.tintColor = [UIColor systemRedColor];
    }

    return cell;
}

/// A still is 16:9 and a table would letterbox it into a square. Sized here, where the
/// cell's own layout has already run and the frame can simply be set.
- (void)tableView:(UITableView *)tableView
   willDisplayCell:(UITableViewCell *)cell
 forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (self.kind != SCIYTJobKindVideo || !cell.imageView.image) return;

    CGFloat height = 60;
    CGFloat width = height * 16.0 / 9.0;
    cell.imageView.frame = CGRectMake(12, (cell.contentView.bounds.size.height - height) / 2,
                                      width, height);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.rows.count) return;

    SCIYTJob *job = self.rows[(NSUInteger)indexPath.row];
    if (job.state != SCIYTJobStateDone) return;

    if (![job fileURL]) { [[SCIYTLibrary shared] remove:job]; return; }

    // Everything that is playable in this list, in the order it is shown. The row that
    // was tapped is where it starts, and next runs down the rest.
    NSMutableArray<SCIYTJob *> *queue = [NSMutableArray array];
    NSUInteger start = 0;
    for (SCIYTJob *candidate in self.rows) {
        if (candidate.state != SCIYTJobStateDone) continue;
        if (candidate == job) start = queue.count;
        [queue addObject:candidate];
    }

    [SCIYTPlayer presentFrom:self jobs:queue start:start];
}

// MARK: - Swipes

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
        // Asked first. A swipe is easy to make by accident on a list you are scrolling,
        // and what it destroys took minutes to fetch and cannot be recovered -- the file is
        // gone from the device, not moved to a bin.
        [self confirmDelete:job then:^{
            [SCIYTThumbnails forget:job];
            [[SCIYTLibrary shared] remove:job];
        }];
        done(YES);
    }];

    if (job.state != SCIYTJobStateDone) {
        return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
    }

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
            if (!ok) {
                [self say:detail ?: SCILocalized(@"dl_failed")];
                return;
            }

            // Kept in both places unless asked otherwise. Photos is where a video goes to
            // be kept; the Centre is where it goes to be played -- and deciding for someone
            // that they wanted only one of those is not this tweak's call. The switch is
            // there for anyone who does not want two copies of everything.
            if (!SCIPrefEnabled(SCIPrefTidyAfterPhotos)) {
                [self say:SCILocalized(@"dl_saved")];
                return;
            }

            [SCIYTThumbnails forget:job];
            [[SCIYTLibrary shared] remove:job];
            [self say:SCILocalized(@"dl_saved_and_removed")];
        }];
        done(YES);
    }];
    photos.backgroundColor = SCIAccent();

    UIContextualAction *rename =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                title:SCILocalized(@"dl_rename")
                                              handler:^(UIContextualAction *action,
                                                        UIView *source,
                                                        void (^done)(BOOL)) {
        [self askToRename:job];
        done(YES);
    }];
    rename.backgroundColor = [UIColor systemGrayColor];

    // Sound has no place in Photos, so that action is not offered for it at all rather
    // than offered and then refused.
    return (self.kind == SCIYTJobKindAudio)
        ? [UISwipeActionsConfiguration configurationWithActions:@[remove, rename, share]]
        : [UISwipeActionsConfiguration configurationWithActions:@[remove, rename, photos, share]];
}

/// Asks before destroying something, and says what.
///
/// Named rather than generic: "Delete this?" beside a list of forty saves is a question
/// nobody can answer confidently. The title is in the message.
/// The little mark on the row that is playing.
///
/// Three bars, the middle one taller, drawn rather than an SF Symbol -- the equaliser glyphs
/// Apple ships are all animated-looking without animating, which reads as broken. Static and
/// deliberate is better than still and pretending.
- (UIView *)playingMark {
    UIView *mark = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 14)];

    CGFloat heights[3] = {8, 14, 10};
    for (int i = 0; i < 3; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:
            CGRectMake(i * 6, (14 - heights[i]) / 2, 3, heights[i])];
        bar.backgroundColor = SCIAccent();
        bar.layer.cornerRadius = 1.5;
        [mark addSubview:bar];
    }
    return mark;
}

- (void)confirmDelete:(SCIYTJob *)job then:(void (^)(void))go {
    UIAlertController *ask = [UIAlertController
        alertControllerWithTitle:SCILocalized(@"dl_delete_title")
                         message:[NSString stringWithFormat:SCILocalized(@"dl_delete_body"),
                                  job.title ?: @""]
                  preferredStyle:UIAlertControllerStyleAlert];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"delete")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(__unused UIAlertAction *action) {
        if (go) go();
    }]];

    [self presentViewController:ask animated:YES completion:nil];
}

- (void)askToRename:(SCIYTJob *)job {
    UIAlertController *ask =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_rename")
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];

    [ask addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = job.title;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;

        // Selected rather than left with the caret at the end. Renaming usually means
        // replacing, and making someone hold backspace through a YouTube title is a small
        // cruelty.
        field.selectedTextRange = [field textRangeFromPosition:field.beginningOfDocument
                                                    toPosition:field.endOfDocument];
    }];

    __weak __typeof(self) weakSelf = self;
    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                            style:UIAlertActionStyleDefault
                                          handler:^(__unused UIAlertAction *action) {
        NSString *typed = ask.textFields.firstObject.text;
        if (![[SCIYTLibrary shared] rename:job to:typed]) {
            [weakSelf say:SCILocalized(@"dl_rename_failed")];
        }
    }]];

    [ask addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

    [self presentViewController:ask animated:YES completion:nil];
}

- (void)share:(SCIYTJob *)job from:(UIView *)source {
    NSURL *file = [job fileURL];
    if (!file) return;

    UIActivityViewController *sheet =
        [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];

    UIView *anchor = source ?: self.view;
    sheet.popoverPresentationController.sourceView = anchor;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(anchor.bounds), CGRectGetMidY(anchor.bounds), 1, 1);

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
