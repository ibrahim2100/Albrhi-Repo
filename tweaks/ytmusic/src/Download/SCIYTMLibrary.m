#import "SCIYTMLibrary.h"

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation SCIYTMTrack
@end

NSString *SCIYTMLibraryFolder(void) {
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"Albrhi"];

    [[NSFileManager defaultManager] createDirectoryAtPath:folder
                              withIntermediateDirectories:YES attributes:nil error:nil];
    return folder;
}

NSArray<SCIYTMTrack *> *SCIYTMSavedTracks(void) {
    NSString *folder = SCIYTMLibraryFolder();
    NSFileManager *files = [NSFileManager defaultManager];

    NSArray<NSString *> *names = [files contentsOfDirectoryAtPath:folder error:nil];
    NSMutableArray<SCIYTMTrack *> *tracks = [NSMutableArray array];

    for (NSString *name in names) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"m4a"]) continue;

        NSString *path = [folder stringByAppendingPathComponent:name];
        NSDictionary *attributes = [files attributesOfItemAtPath:path error:nil];

        SCIYTMTrack *track = [[SCIYTMTrack alloc] init];
        track.url = [NSURL fileURLWithPath:path];
        track.bytes = [attributes fileSize];

        // "Artist - Title.m4a" is what the downloader writes, and a file somebody renamed by hand
        // still shows up -- as its own name, with no artist. The name is the metadata here.
        NSString *base = name.stringByDeletingPathExtension;
        NSRange dash = [base rangeOfString:@" - "];

        if (dash.location != NSNotFound) {
            track.artist = [base substringToIndex:dash.location];
            track.title = [base substringFromIndex:NSMaxRange(dash)];
        } else {
            track.title = base;
        }

        [tracks addObject:track];
    }

    [tracks sortUsingComparator:^NSComparisonResult(SCIYTMTrack *a, SCIYTMTrack *b) {
        NSDate *left = [[files attributesOfItemAtPath:a.url.path error:nil] fileModificationDate];
        NSDate *right = [[files attributesOfItemAtPath:b.url.path error:nil] fileModificationDate];
        return [right compare:left];
    }];

    return tracks;
}

// MARK: - Playing

static AVPlayer *sciPlayer = nil;
static NSArray<SCIYTMTrack *> *sciQueue = nil;
static NSUInteger sciIndex = 0;
static id sciEndObserver = nil;

NSURL *SCIYTMNowPlayingURL(void) {
    AVURLAsset *asset = (AVURLAsset *)sciPlayer.currentItem.asset;
    return [asset isKindOfClass:[AVURLAsset class]] ? asset.URL : nil;
}

static void SCIYTMDescribeToSystem(SCIYTMTrack *track) {
    if (!track) return;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = track.title ?: @"";
    if (track.artist.length) info[MPMediaItemPropertyArtist] = track.artist;

    CMTime duration = sciPlayer.currentItem.asset.duration;
    if (CMTIME_IS_NUMERIC(duration)) {
        info[MPMediaItemPropertyPlaybackDuration] = @(CMTimeGetSeconds(duration));
    }

    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(sciPlayer.currentTime));
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(sciPlayer.rate);

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

static void SCIYTMPlayAt(NSUInteger index);

///
/// The remote commands, taken once.
///
/// **Handing them back is not attempted, and that is a deliberate limit.** Whoever registers last
/// owns the Lock Screen; when this stops playing, YouTube Music takes them again the next time it
/// starts something. Trying to restore them by hand is a race with the app over state neither side
/// owns, and losing it silently is worse than the honest behaviour.
///
static void SCIYTMTakeCommands(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        MPRemoteCommandCenter *centre = [MPRemoteCommandCenter sharedCommandCenter];

        [centre.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            [sciPlayer play];
            SCIYTMDescribeToSystem(sciQueue.count > sciIndex ? sciQueue[sciIndex] : nil);
            return MPRemoteCommandHandlerStatusSuccess;
        }];

        [centre.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            [sciPlayer pause];
            SCIYTMDescribeToSystem(sciQueue.count > sciIndex ? sciQueue[sciIndex] : nil);
            return MPRemoteCommandHandlerStatusSuccess;
        }];

        [centre.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            if (sciIndex + 1 >= sciQueue.count) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            SCIYTMPlayAt(sciIndex + 1);
            return MPRemoteCommandHandlerStatusSuccess;
        }];

        [centre.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            if (sciIndex == 0) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
            SCIYTMPlayAt(sciIndex - 1);
            return MPRemoteCommandHandlerStatusSuccess;
        }];
    });
}

static void SCIYTMPlayAt(NSUInteger index) {
    if (index >= sciQueue.count) return;
    sciIndex = index;

    SCIYTMTrack *track = sciQueue[index];

    // The app's own session category is left alone: YouTube Music has already set it up for
    // background audio, and a second opinion about the audio session is how two players end up
    // fighting over the route.
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:track.url];

    if (!sciPlayer) {
        sciPlayer = [AVPlayer playerWithPlayerItem:item];
    } else {
        [sciPlayer replaceCurrentItemWithPlayerItem:item];
    }

    if (sciEndObserver) [[NSNotificationCenter defaultCenter] removeObserver:sciEndObserver];

    sciEndObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                    object:item
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(__unused NSNotification *note) {
        if (sciIndex + 1 < sciQueue.count) SCIYTMPlayAt(sciIndex + 1);
    }];

    [sciPlayer play];

    SCIYTMTakeCommands();
    SCIYTMDescribeToSystem(track);
}

SCIYTMTrack *SCIYTMCurrentTrack(void) {
    return sciIndex < sciQueue.count ? sciQueue[sciIndex] : nil;
}

BOOL SCIYTMIsPlaying(void) {
    return sciPlayer && sciPlayer.rate > 0.01;
}

void SCIYTMTogglePlayPause(void) {
    if (!sciPlayer) return;

    if (SCIYTMIsPlaying()) {
        [sciPlayer pause];
    } else {
        // Re-asserted on every resume. The app takes the session back whenever its own player
        // starts, and a track resumed after that would otherwise play into a route somebody
        // else owns -- which is what "I cannot start it again" looks like from outside.
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [sciPlayer play];
    }
    SCIYTMDescribeToSystem(SCIYTMCurrentTrack());
}

void SCIYTMNext(void) {
    if (sciIndex + 1 < sciQueue.count) SCIYTMPlayAt(sciIndex + 1);
}

void SCIYTMPrevious(void) {
    // Back to the start of this track first, which is what every music player does and what
    // makes a single press useful when there is nothing before it.
    double elapsed = CMTimeGetSeconds(sciPlayer.currentTime);
    if (elapsed > 3 || sciIndex == 0) {
        SCIYTMSeekTo(0);
        return;
    }
    SCIYTMPlayAt(sciIndex - 1);
}

void SCIYTMProgress(double *elapsed, double *duration) {
    if (elapsed) *elapsed = 0;
    if (duration) *duration = 0;
    if (!sciPlayer.currentItem) return;

    double now = CMTimeGetSeconds(sciPlayer.currentTime);
    double total = CMTimeGetSeconds(sciPlayer.currentItem.duration);

    if (elapsed && isfinite(now)) *elapsed = now;
    if (duration && isfinite(total)) *duration = total;
}

void SCIYTMSeekTo(double seconds) {
    if (!sciPlayer.currentItem) return;

    [sciPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)
          toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    SCIYTMDescribeToSystem(SCIYTMCurrentTrack());
}

void SCIYTMPlay(SCIYTMTrack *track, NSArray<SCIYTMTrack *> *queue) {
    sciQueue = queue.count ? queue : (track ? @[track] : @[]);

    NSUInteger index = [sciQueue indexOfObjectPassingTest:^BOOL(SCIYTMTrack *entry, NSUInteger idx, BOOL *stop) {
        return [entry.url isEqual:track.url];
    }];

    SCIYTMPlayAt(index == NSNotFound ? 0 : index);
}
