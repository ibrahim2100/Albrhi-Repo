#import "SCIYTMDownload.h"
#import "SCIYTMLibrary.h"
#import "../YTMShared.h"
#import "../Localization/SCILocalize.h"

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface ELMNodeController : NSObject
@property (nonatomic, copy, readonly) NSString *key;
@end

@interface ELMTouchCommandPropertiesHandler : NSObject
@end

// MARK: - Reading the app's own model, without running its code on faith

///
/// `-valueForKey:` is not a safe probe -- it runs the app's own getter, and this project crashed
/// Instagram once by trusting `@catch` to make that harmless. Every hop below asks the runtime
/// whether the key is real before touching it, and answers nil when it is not.
///
static id SCIYTMValue(id object, NSString *key) {
    if (!object || !key.length) return nil;

    SEL getter = NSSelectorFromString(key);
    if ([object respondsToSelector:getter]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, getter);
    }

    NSString *ivar = [@"_" stringByAppendingString:key];
    if (class_getInstanceVariable([object class], ivar.UTF8String) == NULL) return nil;

    @try {
        return [object valueForKey:key];
    } @catch (__unused id error) {
        return nil;
    }
}

static NSString *SCIYTMString(id object, NSString *key) {
    id value = SCIYTMValue(object, key);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

// MARK: - The manifest

///
/// The audio rendition, taken from the master playlist.
///
/// YouTube's audio groups are itag numbers: 234 is the higher bitrate, 233 the lower. They are
/// tried in that order and then **any** `TYPE=AUDIO` line is accepted, because a group id is a
/// name and this project has been burned four times by treating a name as a guarantee. A manifest
/// that offers audio under a third number still downloads.
///
static NSString *SCIYTMAudioURI(NSString *manifest) {
    if (!manifest.length) return nil;

    NSArray<NSString *> *lines =
        [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSArray<NSString *> *preferred = @[@"TYPE=AUDIO,GROUP-ID=\"234\"",
                                       @"TYPE=AUDIO,GROUP-ID=\"233\"",
                                       @"TYPE=AUDIO"];

    for (NSString *needle in preferred) {
        for (NSString *line in lines) {
            if (![line containsString:needle]) continue;

            NSRange start = [line rangeOfString:@"https://"];
            if (start.location == NSNotFound) continue;

            // The URI runs to the end of the line, or to the closing quote when the attribute is
            // quoted -- both shapes appear, and cutting at a fixed filename would refuse one.
            NSUInteger from = start.location;
            NSRange quote = [line rangeOfString:@"\"" options:0
                                          range:NSMakeRange(from, line.length - from)];
            NSUInteger to = (quote.location != NSNotFound) ? quote.location : line.length;

            NSString *uri = [[line substringWithRange:NSMakeRange(from, to - from)]
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (uri.length) return uri;
        }
    }

    return nil;
}

/// Every segment in a media playlist, made absolute.
static NSArray<NSURL *> *SCIYTMSegments(NSString *playlist, NSURL *base) {
    NSMutableArray<NSURL *> *segments = [NSMutableArray array];

    for (NSString *raw in [playlist componentsSeparatedByCharactersInSet:
                            [NSCharacterSet newlineCharacterSet]]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
        if (!line.length || [line hasPrefix:@"#"]) continue;

        NSURL *url = [line hasPrefix:@"http"] ? [NSURL URLWithString:line]
                                              : [NSURL URLWithString:line relativeToURL:base];
        if (url) [segments addObject:url.absoluteURL];
    }

    return segments;
}

// MARK: - Packed audio

///
/// An ID3v2 tag's length, or zero when there is not one here.
///
/// **YouTube's audio segments are packed ADTS behind an ID3 tag -- one tag per segment.** Joining
/// the segments and handing the result to AVFoundation gives a file with twenty-odd tags buried in
/// it, which is what "the download had no audio track" turned out to be in the YouTube tweak. The
/// same five constraints are checked here as there: the three letters, a version that is not 0xFF,
/// and four syncsafe length bytes -- together, chance does not meet them.
///
static NSUInteger SCIYTMID3Length(const uint8_t *bytes, NSUInteger at, NSUInteger length) {
    if (at + 10 > length) return 0;
    if (bytes[at] != 'I' || bytes[at + 1] != 'D' || bytes[at + 2] != '3') return 0;
    if (bytes[at + 3] == 0xFF || bytes[at + 4] == 0xFF) return 0;

    for (int i = 6; i < 10; i++) {
        if (bytes[at + i] & 0x80) return 0;
    }

    NSUInteger size = ((NSUInteger)bytes[at + 6] << 21) | ((NSUInteger)bytes[at + 7] << 14)
                    | ((NSUInteger)bytes[at + 8] << 7)  |  (NSUInteger)bytes[at + 9];

    return (at + 10 + size <= length) ? 10 + size : 0;
}

/// One segment's audio frames, with its tag taken off the front.
static NSData *SCIYTMStripTag(NSData *segment) {
    if (!segment.length) return segment;

    const uint8_t *bytes = segment.bytes;
    NSUInteger skip = SCIYTMID3Length(bytes, 0, segment.length);

    return skip ? [segment subdataWithRange:NSMakeRange(skip, segment.length - skip)] : segment;
}

// MARK: - Saying what happened

/// A banner in Albrhi's own colours, not a system alert with an OK button.
///
/// **What was here interrupted.** Every finished download put a modal alert on screen and asked
/// for a tap to dismiss something that had gone right -- over a music app, mid-song, for a result
/// nobody needed to acknowledge. A banner says the same thing and takes itself away.
///
/// Failures stay longer than successes and are red rather than tinted: a save that did not happen
/// is the one message here somebody has to actually read.
static void SCIYTMTell(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *key = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { key = window; break; }
        }
        if (!key) return;

        BOOL failed = [title isEqualToString:SCILocalized(@"download_failed")];

        UIView *banner = [[UIView alloc] init];
        banner.translatesAutoresizingMaskIntoConstraints = NO;
        banner.backgroundColor = failed ? [UIColor systemRedColor]
                                        : [UIColor colorWithRed:230/255.0 green:75/255.0
                                                            blue:75/255.0 alpha:1];
        banner.layer.cornerRadius = 16;
        banner.layer.cornerCurve = kCACornerCurveContinuous;
        banner.alpha = 0;

        // The tweak's own mark, so a banner is recognisably Albrhi's rather than an unlabelled
        // rectangle that could have come from the app.
        UIImageView *mark = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:(failed ? @"exclamationmark.triangle.fill"
                                              : @"arrow.down.circle.fill")]];
        mark.tintColor = [UIColor whiteColor];
        mark.contentMode = UIViewContentModeScaleAspectFit;

        UILabel *heading = [[UILabel alloc] init];
        heading.text = title;
        heading.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        heading.textColor = [UIColor whiteColor];

        UILabel *detail = [[UILabel alloc] init];
        detail.text = message;
        detail.font = [UIFont systemFontOfSize:13];
        detail.textColor = [UIColor colorWithWhite:1 alpha:0.85];
        detail.numberOfLines = 3;

        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[heading, detail]];
        text.axis = UILayoutConstraintAxisVertical;
        text.spacing = 2;

        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[mark, text]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.alignment = UIStackViewAlignmentCenter;
        row.spacing = 12;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [banner addSubview:row];
        [key addSubview:banner];

        [NSLayoutConstraint activateConstraints:@[
            [mark.widthAnchor constraintEqualToConstant:26],
            [mark.heightAnchor constraintEqualToConstant:26],
            [row.topAnchor constraintEqualToAnchor:banner.topAnchor constant:12],
            [row.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-12],
            [row.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:14],
            [row.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-14],
            // Below the safe area, so it never sits on the clock -- the mistake the Downloads
            // page itself made.
            [banner.topAnchor constraintEqualToAnchor:key.safeAreaLayoutGuide.topAnchor constant:8],
            [banner.leadingAnchor constraintGreaterThanOrEqualToAnchor:key.leadingAnchor constant:12],
            [banner.trailingAnchor constraintLessThanOrEqualToAnchor:key.trailingAnchor constant:-12],
            [banner.centerXAnchor constraintEqualToAnchor:key.centerXAnchor],
        ]];

        banner.transform = CGAffineTransformMakeTranslation(0, -20);
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.8
              initialSpringVelocity:0 options:0 animations:^{
            banner.alpha = 1;
            banner.transform = CGAffineTransformIdentity;
        } completion:nil];

        [UIView animateWithDuration:0.25 delay:(failed ? 4.5 : 2.2) options:0 animations:^{
            banner.alpha = 0;
            banner.transform = CGAffineTransformMakeTranslation(0, -20);
        } completion:^(__unused BOOL finished) {
            [banner removeFromSuperview];
        }];
    });
}

/// A name a file system will take, from a title a person wrote.
static NSString *SCIYTMSafeName(NSString *name) {
    NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    NSString *cleaned = [[name componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@" "];

    cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return cleaned.length ? cleaned : @"track";
}

// MARK: - The download

///
/// Fetches the master playlist, then the audio playlist, then every segment, and remuxes the
/// result to `.m4a`.
///
/// **`AVAssetExportPresetPassthrough` is the whole reason FFmpeg is not here.** The segments are
/// already AAC; nothing is decoded and nothing is re-encoded, which is what `-c copy` meant in the
/// port this was measured against. What the export does is put those frames in an MPEG-4 container
/// so the Files app, the Music app and anything else can read them.
///
static void SCIYTMDownloadTrack(NSURL *manifestURL, NSString *title, NSString *artist,
                                NSString *chosenName, NSString *section) {
    NSURLSession *session = [NSURLSession sharedSession];

    [[session dataTaskWithURL:manifestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *master = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSString *audioURI = SCIYTMAudioURI(master);

        if (!audioURI.length) {
            SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_no_audio"));
            return;
        }

        NSURL *audioURL = [NSURL URLWithString:audioURI];
        [[session dataTaskWithURL:audioURL completionHandler:^(NSData *listData, NSURLResponse *listResponse, NSError *listError) {
            NSString *playlist = listData.length ? [[NSString alloc] initWithData:listData encoding:NSUTF8StringEncoding] : nil;
            NSArray<NSURL *> *segments = SCIYTMSegments(playlist, audioURL);

            if (!segments.count) {
                SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_no_segments"));
                return;
            }

            //
            // Fetched one after another rather than all at once. A track is a few hundred small
            // segments; forty simultaneous connections is how a server decides to slow a client
            // down, and the ordering here has to be exact anyway.
            //
            NSMutableData *audio = [NSMutableData data];

            for (NSURL *segment in segments) {
                NSData *part = [NSData dataWithContentsOfURL:segment];
                if (!part.length) continue;
                [audio appendData:SCIYTMStripTag(part)];
            }

            if (!audio.length) {
                SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_empty"));
                return;
            }

            NSString *folder = SCIYTMLibraryFolder();
            if (section.length) {
                folder = [folder stringByAppendingPathComponent:SCIYTMSafeName(section)];
            }
            [[NSFileManager defaultManager] createDirectoryAtPath:folder
                                      withIntermediateDirectories:YES attributes:nil error:nil];

            // The name the person typed wins; the artist-and-title pair is only the suggestion
            // it started from. Sanitised either way -- a slash in a name is a directory nobody
            // asked for.
            NSString *name = chosenName.length
                ? SCIYTMSafeName(chosenName)
                : (artist.length ? [NSString stringWithFormat:@"%@ - %@",
                                    SCIYTMSafeName(artist), SCIYTMSafeName(title)]
                                 : SCIYTMSafeName(title));

            NSURL *raw = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.aac", name]]];
            NSURL *final = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@.m4a", name]]];

            [[NSFileManager defaultManager] removeItemAtURL:raw error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:final error:nil];

            if (![audio writeToURL:raw atomically:YES]) {
                SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_not_written"));
                return;
            }

            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:raw options:nil];

            //
            // The length is waited for before anything is asked of it. A raw AAC file has no index,
            // so until AVFoundation has read it the track's `timeRange` is not a number -- and a
            // range built from that is what "the operation could not be completed" was in the
            // YouTube tweak, with nothing wrong in the media at all.
            //
            [asset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^{
                AVAssetExportSession *export =
                    [[AVAssetExportSession alloc] initWithAsset:asset
                                                     presetName:AVAssetExportPresetPassthrough];
                export.outputURL = final;
                export.outputFileType = AVFileTypeAppleM4A;

                [export exportAsynchronouslyWithCompletionHandler:^{
                    [[NSFileManager defaultManager] removeItemAtURL:raw error:nil];

                    if (export.status == AVAssetExportSessionStatusCompleted) {
                        SCIYTMTell(SCILocalized(@"download_saved"),
                            [NSString stringWithFormat:SCILocalized(@"download_saved_at"), name]);
                    } else {
                        SCIYTMTell(SCILocalized(@"download_failed"),
                            export.error.localizedDescription ?: SCILocalized(@"download_remux_failed"));
                    }
                }];
            }];
        }] resume];
    }] resume];
}

///
/// The view controller a view belongs to, without betting on a private method.
///
/// **This is where 0.8.1 crashed, and 0.8.0 did not — for a reason worth keeping.** The old code
/// called `-_viewControllerForAncestor`, a private `UIView` method, as the *second* operand of an
/// `||` whose first operand never matched. Short-circuit evaluation meant it was never reached; the
/// moment 0.8.1 widened the key match, the tap arrived there for the first time and the selector
/// was not on this build.
///
/// **A crash that appears when a feature starts working was not introduced by the change that
/// exposed it.** The private method is still tried, because it is exact when it exists, and the
/// responder chain answers the same question with public API when it does not.
///
static UIViewController *SCIYTMOwningController(UIView *view) {
    if (!view) return nil;

    SEL ancestor = NSSelectorFromString(@"_viewControllerForAncestor");
    if ([view respondsToSelector:ancestor]) {
        id owner = ((id (*)(id, SEL))objc_msgSend)(view, ancestor);
        if ([owner isKindOfClass:[UIViewController class]]) return owner;
    }

    for (UIResponder *responder = view; responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
    }

    return nil;
}

// MARK: - What the tap actually was

///
/// The last few node keys this handler saw, for the one question a failure here raises: *what is
/// the download badge called on this build?*
///
/// A counter would not answer it and a log nobody reads is not a diagnostic -- these are shown on
/// the Downloads screen when nothing has been saved, which is exactly when somebody is asking.
///
static NSMutableArray<NSString *> *sciSeenKeys = nil;
static BOOL sciDownloadInstalled = NO;
static NSUInteger sciTapsSeen = 0, sciBadgeTaps = 0, sciNoManifest = 0, sciStarted = 0;

void SCIYTMRememberKey(NSString *key) {
    if (!key.length) return;

    static dispatch_once_t once;
    dispatch_once(&once, ^{ sciSeenKeys = [NSMutableArray array]; });

    if ([sciSeenKeys containsObject:key]) return;

    [sciSeenKeys addObject:key];
    while (sciSeenKeys.count > 12) [sciSeenKeys removeObjectAtIndex:0];
}

NSArray<NSString *> *SCIYTMSeenKeys(void) {
    return [sciSeenKeys copy] ?: @[];
}

/// The player controller behind a view on the now-playing screen.
///
/// **The property is on the parent, and asking the wrong controller is the whole of the bug this
/// replaces.** `YTMNowPlayingViewController` does not declare `playerViewController` --
/// `YTMWatchViewController`, its parent, does. The long press walked to the parent and worked; the
/// badge asked the now-playing controller directly, got nil, and reported *the badge was found but
/// this track carries no stream* — a message that describes the track when the fault was the
/// lookup. **Two doors resolving the same thing two ways is two chances to be wrong**, and only one
/// of them was.
///
/// Both parents are tried and then the owner itself, so a build that moves the property back down
/// still answers.
static id SCIYTMPlayerControllerNear(UIView *view) {
    UIViewController *owner = SCIYTMOwningController(view);
    if (!owner) return nil;

    UIViewController *candidates[] = { owner.parentViewController,
                                       owner.parentViewController.parentViewController,
                                       owner };
    for (int i = 0; i < 3; i++) {
        id player = SCIYTMValue(candidates[i], @"playerViewController")
                 ?: SCIYTMValue(candidates[i], @"playerVC");
        if (player) return player;
    }
    return nil;
}

/// The sections that already exist under the library folder.
///
/// Read from disk rather than kept in a preference: the folder *is* the truth, so a section made
/// in the Files app appears here and one deleted there stops being offered, with no state of ours
/// to fall out of step. The same reasoning the library itself is built on.
static NSArray<NSString *> *SCIYTMSections(void) {
    NSString *root = SCIYTMLibraryFolder();
    NSMutableArray<NSString *> *sections = [NSMutableArray array];

    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:nil]) {
        BOOL directory = NO;
        NSString *path = [root stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory] && directory) {
            [sections addObject:name];
        }
    }
    return [sections sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

/// Asks before saving: what to call it, and where to put it.
///
/// **A confirmation, not an interruption.** The name is filled in with what the track is already
/// called, and the section defaults to the last one used, so the whole thing is one tap for anybody
/// who does not care -- and two fields for anybody who does. Nothing is fetched until it is
/// confirmed, so cancelling costs nothing.
static void SCIYTMAskThenDownload(NSString *manifest, NSString *title, NSString *artist) {
    NSString *suggested = artist.length
        ? [NSString stringWithFormat:@"%@ - %@", artist, title]
        : (title ?: @"track");

    NSString *lastSection =
        [[NSUserDefaults standardUserDefaults] stringForKey:@"AlbrhiYTMLastSection"] ?: @"";

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dl_confirm_title")
                                            message:SCILocalized(@"dl_confirm_note")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = suggested;
        field.placeholder = SCILocalized(@"dl_confirm_name");
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = lastSection;
        // The existing sections are named in the placeholder rather than in a picker: a list of
        // folders is short, and a free field is the only thing that can also *make* one.
        NSArray<NSString *> *existing = SCIYTMSections();
        field.placeholder = existing.count
            ? [NSString stringWithFormat:@"%@ — %@", SCILocalized(@"dl_confirm_section"),
               [existing componentsJoinedByString:@", "]]
            : SCILocalized(@"dl_confirm_section");
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dl_confirm_save")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *name = sheet.textFields.firstObject.text;
        NSString *section = sheet.textFields.lastObject.text;

        [[NSUserDefaults standardUserDefaults] setObject:(section ?: @"")
                                                  forKey:@"AlbrhiYTMLastSection"];

        sciStarted++;
        SCIYTMTell(SCILocalized(@"download_started"), SCILocalized(@"download_started_note"));
        SCIYTMDownloadTrack([NSURL URLWithString:manifest], title, artist, name, section);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIViewController *top = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { top = window.rootViewController; break; }
    }
    while (top.presentedViewController) top = top.presentedViewController;

    // No screen to ask on is not a reason to save something nobody confirmed -- and not a reason
    // to lose the download either. It goes ahead with the suggested name and the last section,
    // which is exactly what the sheet would have offered.
    if (!top) {
        sciStarted++;
        SCIYTMDownloadTrack([NSURL URLWithString:manifest], title, artist, suggested, lastSection);
        return;
    }

    [top presentViewController:sheet animated:YES completion:nil];
}

// MARK: - A surface of our own

///
/// A long press anywhere on the now-playing screen offers the download.
///
/// **Because the badge is not ours and never was.** Its key is generated by the server for an
/// Elements component -- `music_download_badge_1` is nowhere in YouTube Music's own binary, and the
/// reference tweak still matches that exact literal, which means the name is a server template's
/// and can differ per account, per experiment, per build. Every release of this feature so far has
/// been a guess about that name, and a guess about somebody else's string is not a foundation.
///
/// This surface is entirely ours: a gesture on a class the app declares, reaching the track through
/// a chain confirmed hop by hop in YouTube Music 8.26.5 --
/// `YTMNowPlayingViewController.parentViewController` is `YTMWatchViewController`, which declares
/// `playerViewController : YTPlayerViewController`, which declares `playerResponse`. Three hops,
/// each naming the next class in its own declared property type.
///
/// The badge hook stays. When it fires it is the better door, because it is where somebody already
/// looks; this is the one that cannot be taken away by a name changing on a server.
///

// Declared because a %hook gets only a forward declaration, and this one reads `self.view`.
@interface YTMNowPlayingViewController : UIViewController
@end

static char kSCIYTMPressAdded;
static BOOL sciPressInstalled = NO;
static NSUInteger sciInstallAttempts = 0;
static NSUInteger sciPressesAdded = 0, sciPressesFired = 0;

@interface SCIYTMPressHandler : NSObject
+ (instancetype)shared;
- (void)handle:(UILongPressGestureRecognizer *)gesture;
@end

@implementation SCIYTMPressHandler

+ (instancetype)shared {
    static SCIYTMPressHandler *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCIYTMPressHandler alloc] init]; });
    return shared;
}

- (void)handle:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    sciPressesFired++;

    id playerVC = SCIYTMPlayerControllerNear(gesture.view);

    id playerResponse = SCIYTMValue(playerVC, @"playerResponse")
                     ?: SCIYTMValue(playerVC, @"contentPlayerResponse");
    id playerData = SCIYTMValue(playerResponse, @"playerData");
    id streaming = SCIYTMValue(playerData, @"streamingData");
    id details = SCIYTMValue(playerData, @"videoDetails");

    NSString *manifest = SCIYTMString(streaming, @"hlsManifestURL");
    if (!manifest.length) {
        SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_no_manifest"));
        return;
    }

    SCIYTMAskThenDownload(manifest,
                          SCIYTMString(details, @"title") ?: @"track",
                          SCIYTMString(details, @"author"));
}

@end


%group SCIYTMPressGroup

%hook YTMNowPlayingViewController

/// `-viewDidLoad` rather than `-viewDidAppear:`, because this build declares the first and not the
/// second -- and a `%hook` on a method a class does not declare adds it, which would be inventing
/// an API the app never calls.
- (void)viewDidLoad {
    %orig;

    UIView *view = self.view;
    if (!view || objc_getAssociatedObject(view, &kSCIYTMPressAdded)) return;
    objc_setAssociatedObject(view, &kSCIYTMPressAdded, @YES, OBJC_ASSOCIATION_RETAIN);

    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[SCIYTMPressHandler shared]
                                                      action:@selector(handle:)];

    // Does not cancel what it sits on: every tap and swipe the player already has keeps working.
    // A gesture that quietly disabled the transport controls would be a feature removing features.
    press.cancelsTouchesInView = NO;
    [view addGestureRecognizer:press];
    sciPressesAdded++;
}

%end

%end


// MARK: - The app's own button

%group SCIYTMDownloadGroup

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    // Counted before anything else, including the enabled check: "did this hook ever run"
    // is the first of the three questions a Premium prompt could be answering, and it is
    // the only one that cannot be worked out afterwards.
    sciTapsSeen++;

    //
    // **The app's own download badge, intercepted before its Premium gate.**
    //
    // Both ivars are confirmed before they are read: `-valueForKey:` on a name a build does not
    // have runs the app's own code on the way to failing, and this project has a crash on record
    // for exactly that. A build without them takes `%orig` and nothing is lost.
    //
    //
    // **The master switch is deliberately not asked here, because upstream does not ask it
    // either.**
    //
    // Its `-handleTap` checks the two ivars, the node key and the ancestor, and nothing
    // else -- `YTMUltimateIsEnabled` gates its *other* features, never this one. This build
    // asked it first, which adds a way for the download to do nothing that the tweak it was
    // ported from does not have: a dictionary written by a different process, an upgrade
    // that lands before the constructor rewrites it, a master switch turned off once and
    // forgotten. The whole tweak is already behind Albrhi's panel gate in `%ctor`; a second
    // gate on one feature is a second way to fail, and this feature has failed enough.
    //
    if (class_getInstanceVariable([self class], "_controller") == NULL ||
        class_getInstanceVariable([self class], "_tapRecognizer") == NULL) {
        %orig;
        return;
    }

    ELMNodeController *node = [self valueForKey:@"_controller"];
    UIGestureRecognizer *recogniser = [self valueForKey:@"_tapRecognizer"];

    //
    // **Matched on what the key means, not on one literal -- and every key seen is remembered.**
    //
    // 0.7.0 demanded `music_download_badge_1` exactly, copied from a reference tweak, and on a real
    // device the tap went straight past it to YouTube Music's own Premium prompt. That is this
    // project's oldest lesson arriving again: **a reference's constant is its build, not yours.**
    //
    // Any node whose key names a download is taken now, and the last few keys are kept so the next
    // report says what this build actually calls it rather than leaving it to be guessed at a
    // second time. The ancestor check is gone with it: the app draws this badge on the now-playing
    // screen, and demanding a class name as well was a second way to miss for no second reason.
    //
    // The ivar holds whatever this build put there. Asking an object for a selector it does not
    // have is an unrecognised selector, not a nil -- and this hook runs on every tap in the app.
    if (![node respondsToSelector:@selector(key)]) {
        %orig;
        return;
    }

    SCIYTMRememberKey(node.key);


    if (!node.key.length ||
        [node.key rangeOfString:@"download" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        %orig;
        return;
    }

    sciBadgeTaps++;

    id playerVC = SCIYTMPlayerControllerNear(recogniser.view);

    id playerResponse = SCIYTMValue(playerVC, @"playerResponse")
                     ?: SCIYTMValue(playerVC, @"contentPlayerResponse");
    id playerData = SCIYTMValue(playerResponse, @"playerData");
    id streaming = SCIYTMValue(playerData, @"streamingData");
    id details = SCIYTMValue(playerData, @"videoDetails");

    NSString *manifest = SCIYTMString(streaming, @"hlsManifestURL");
    if (!manifest.length) {
        //
        // **The badge was ours and the stream was not there, which is a different failure from not
        // recognising the badge -- so it is said differently.**
        //
        // Falling through to `%orig` here would show the Premium prompt and leave the two causes
        // indistinguishable: this project has spent releases on reports that could not separate
        // *the hook never ran* from *the hook ran and found nothing*.
        //
        sciNoManifest++;
        SCIYTMTell(SCILocalized(@"download_failed"), SCILocalized(@"download_no_manifest"));
        return;
    }

    SCIYTMAskThenDownload(manifest,
                          SCIYTMString(details, @"title") ?: @"track",
                          SCIYTMString(details, @"author"));
}

%end

%end

NSString *SCIYTMDownloadReport(void) {
    NSString *tries = [NSString stringWithFormat:@" (%lu install attempt(s))",
                       (unsigned long)sciInstallAttempts];
    NSString *press = sciPressInstalled
        ? [NSString stringWithFormat:@" · long press: %lu screen(s), %lu used",
           (unsigned long)sciPressesAdded, (unsigned long)sciPressesFired]
        : @" · long press: YTMNowPlayingViewController not in this build";

    if (!sciDownloadInstalled) {
        return [[@"the badge class never appeared" stringByAppendingString:press] stringByAppendingString:tries];
    }
    if (sciTapsSeen == 0) {
        return [@"badge hooked, no tap has reached it" stringByAppendingString:press];
    }
    if (sciBadgeTaps == 0) {
        return [[NSString stringWithFormat:@"%lu tap(s) seen, none named a download badge",
                 (unsigned long)sciTapsSeen] stringByAppendingString:press];
    }
    return [[NSString stringWithFormat:@"%lu tap(s), %lu on the badge, %lu started, %lu with no stream",
             (unsigned long)sciTapsSeen, (unsigned long)sciBadgeTaps,
             (unsigned long)sciStarted, (unsigned long)sciNoManifest] stringByAppendingString:press];
}

/// Installs whichever of the two doors this build has, and says how many tries it took.
///
/// **Both classes reported "not in this build" on a device that certainly has them** -- the badge
/// handler and the now-playing controller are both in YouTube Music's own binary, read out of it
/// directly. What was wrong was *when* they were asked: a tweak's `%ctor` runs before the app's own
/// Objective-C metadata is registered, so `NSClassFromString` answers nil for a class that will
/// exist a moment later. The answer is not "the class is missing" -- it is "you asked too early",
/// and the two are indistinguishable from a single call.
///
/// So the question is asked again: once when the app says it has finished launching, and once more
/// on a short delay for a build that installs these classes later still. Each attempt is counted,
/// and the report says which one succeeded -- because "worked on the second try" and "worked
/// immediately" are different facts about a build, and only one of them means the constructor is
/// the right place.
static void SCIYTMTryInstall(void) {
    sciInstallAttempts++;

    if (!sciPressInstalled && NSClassFromString(@"YTMNowPlayingViewController")) {
        %init(SCIYTMPressGroup);
        sciPressInstalled = YES;
    }

    if (!sciDownloadInstalled && NSClassFromString(@"ELMTouchCommandPropertiesHandler")) {
        %init(SCIYTMDownloadGroup);
        sciDownloadInstalled = YES;
    }
}

NSUInteger SCIYTMInstallAttempts(void) { return sciInstallAttempts; }

void SCIYTMInstallDownload(void) {
    SCIYTMTryInstall();
    if (sciPressInstalled && sciDownloadInstalled) return;

    // Asked again when the app itself says it is up. `%init` on a group already initialised
    // would install the same hooks twice, so each group is guarded by its own flag rather
    // than by whether this function has run before.
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(__unused NSNotification *note) { SCIYTMTryInstall(); }];

    // And once more after that, for a build whose classes arrive with a framework loaded on
    // first use. Two seconds is long enough to be after launch and short enough to be before
    // anybody has reached a song.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ SCIYTMTryInstall(); });
}
