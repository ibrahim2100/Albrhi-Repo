#import "SCIDownloadQueue.h"
#import "../Download.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Applies the user's post-download action to jobs finished by the queue.
///
/// The queue's only job is to move bytes; what happens to the finished file is a
/// preference. This observer owns that decision so neither side has to know about
/// the other.
///

@interface SCIDownloadQueueBridge : NSObject
@end

@implementation SCIDownloadQueueBridge

static SCIDownloadQueueBridge *_sharedBridge = nil;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedBridge = [[SCIDownloadQueueBridge alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:_sharedBridge
                                                 selector:@selector(queueChanged:)
                                                     name:SCIDownloadQueueDidChangeNotification
                                                   object:nil];
    });
}

- (void)queueChanged:(NSNotification *)note {
    [self sweepFinishedJobs];
}

/// Saves every completed download that hasn't reached Photos yet.
///
/// Acting only on the job carried by a single notification missed transfers that
/// finished while the app was backgrounded, leaving them stranded in the Download
/// Center. Sweeping the whole list makes the save idempotent and self-healing.
- (void)sweepFinishedJobs {
    if (![SCIUtils getBoolPref:@"dw_save_to_camera"]) return;

    for (SCIDownloadJob *job in [SCIDownloadQueue shared].history) {
        if (job.state != SCIDownloadStateCompleted) continue;
        if (job.savedToPhotos || !job.localURL) continue;

        // The file may have been cleared from the cache since.
        if (![[NSFileManager defaultManager] fileExistsAtPath:job.localURL.path]) continue;

        // Claim it before the async save so a second sweep can't double-save.
        job.savedToPhotos = YES;

        [SCIDownloadDelegate saveLocalFileToPhotos:job.localURL];

        if (![SCIUtils getBoolPref:@"dl_clear_after_save"]) continue;

        // The cached copy is pure duplication once it is in Photos. Give the save
        // time to finish reading the file before removing it.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[SCIDownloadQueue shared] discardJobAndFile:job];
        });
    }
}

@end
