#import <Foundation/Foundation.h>
#import "SCIDownloadJob.h"

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main thread whenever any job is added, removed or changes state.
/// `object` is the queue; `userInfo[@"job"]` is the affected job when there is one.
extern NSNotificationName const SCIDownloadQueueDidChangeNotification;

///
/// The download queue.
///
/// A single background `NSURLSession` drives every transfer, so downloads survive
/// the app being backgrounded and resume after a relaunch. Concurrency is capped
/// so a carousel doesn't saturate the connection.
///
/// All mutation funnels through a serial queue; every notification is delivered on
/// the main thread. Callers never need to think about threading.
///

@interface SCIDownloadQueue : NSObject

@property (class, nonatomic, readonly) SCIDownloadQueue *shared;

/// Jobs still in flight — queued, downloading or paused. Newest last.
@property (nonatomic, readonly) NSArray<SCIDownloadJob *> *activeJobs;

/// Completed, failed and cancelled jobs. Newest first. Capped and persisted.
@property (nonatomic, readonly) NSArray<SCIDownloadJob *> *history;

/// How many transfers may run at once. Persisted as `dl_max_concurrent`.
@property (nonatomic) NSInteger maxConcurrentDownloads;

// MARK: - Enqueueing

/// Adds a download. Returns the job, or the existing one when `url` is already
/// queued or in flight (duplicate detection).
- (SCIDownloadJob *)enqueueURL:(NSURL *)url
                 fileExtension:(nullable NSString *)fileExtension
                   displayName:(nullable NSString *)displayName
                   sourceLabel:(nullable NSString *)sourceLabel;

/// Whether this URL was already downloaded successfully and the file still exists.
- (nullable SCIDownloadJob *)completedJobForURL:(NSURL *)url;

// MARK: - Control

- (void)pauseJob:(SCIDownloadJob *)job;
- (void)resumeJob:(SCIDownloadJob *)job;
- (void)retryJob:(SCIDownloadJob *)job;
- (void)cancelJob:(SCIDownloadJob *)job;

- (void)pauseAll;
- (void)resumeAll;
- (void)cancelAll;

// MARK: - History

- (void)removeJobFromHistory:(SCIDownloadJob *)job;
- (void)clearHistory;

/// Total bytes of every successful download ever recorded.
- (int64_t)totalBytesDownloaded;

@end

NS_ASSUME_NONNULL_END
