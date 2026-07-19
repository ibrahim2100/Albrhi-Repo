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
static NSMutableSet<NSString *> *_handledJobIdentifiers = nil;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedBridge = [[SCIDownloadQueueBridge alloc] init];
        _handledJobIdentifiers = [NSMutableSet set];

        [[NSNotificationCenter defaultCenter] addObserver:_sharedBridge
                                                 selector:@selector(queueChanged:)
                                                     name:SCIDownloadQueueDidChangeNotification
                                                   object:nil];
    });
}

- (void)queueChanged:(NSNotification *)note {
    SCIDownloadJob *job = note.userInfo[@"job"];

    if (job.state != SCIDownloadStateCompleted || !job.localURL) return;

    // The queue posts a change notification for every observer; only act once per job.
    if ([_handledJobIdentifiers containsObject:job.identifier]) return;
    [_handledJobIdentifiers addObject:job.identifier];

    if ([SCIUtils getBoolPref:@"dw_save_to_camera"]) {
        [SCIDownloadDelegate saveLocalFileToPhotos:job.localURL];
        return;
    }

    // Otherwise the file simply waits in the Download Center, where tapping the
    // row opens it. A toast confirms it landed without stealing focus.
    [SCIUtils showToastForDuration:1.6
                             title:SCILocalized(@"download_saved")
                          subtitle:job.displayName];
}

@end
