#import "SCIDownloadQueue.h"

NSNotificationName const SCIDownloadQueueDidChangeNotification = @"SCIDownloadQueueDidChangeNotification";

static NSString *const SCIBackgroundSessionIdentifier = @"com.albrhi.downloads.background";
static NSInteger const SCIHistoryLimit = 250;

@interface SCIDownloadQueue () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) dispatch_queue_t stateQueue;

@property (nonatomic, strong) NSMutableArray<SCIDownloadJob *> *mutableActive;
@property (nonatomic, strong) NSMutableArray<SCIDownloadJob *> *mutableHistory;

/// job.identifier -> live task
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *tasks;
/// job.identifier -> resume data captured on pause
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *resumeData;
/// job.identifier -> @[lastSampleDate, lastSampleBytes] for throughput
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray *> *throughputSamples;

@end

@implementation SCIDownloadQueue

+ (SCIDownloadQueue *)shared {
    static SCIDownloadQueue *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SCIDownloadQueue alloc] init];
    });

    return shared;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _stateQueue = dispatch_queue_create("com.albrhi.downloadqueue", DISPATCH_QUEUE_SERIAL);
    _mutableActive = [NSMutableArray array];
    _mutableHistory = [NSMutableArray array];
    _tasks = [NSMutableDictionary dictionary];
    _resumeData = [NSMutableDictionary dictionary];
    _throughputSamples = [NSMutableDictionary dictionary];

    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:SCIBackgroundSessionIdentifier];
    config.sessionSendsLaunchEvents = YES;
    config.discretionary = NO;

    _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

    [self loadHistory];

    return self;
}

// MARK: - Concurrency

- (NSInteger)maxConcurrentDownloads {
    NSInteger stored = [[NSUserDefaults standardUserDefaults] integerForKey:@"dl_max_concurrent"];
    return stored > 0 ? stored : 3;
}

- (void)setMaxConcurrentDownloads:(NSInteger)value {
    [[NSUserDefaults standardUserDefaults] setInteger:MAX(1, value) forKey:@"dl_max_concurrent"];

    [self pumpQueue];
}

// MARK: - Accessors

- (NSArray<SCIDownloadJob *> *)activeJobs {
    __block NSArray *snapshot = nil;
    dispatch_sync(self.stateQueue, ^{
        snapshot = [self.mutableActive copy];
    });

    return snapshot;
}

- (NSArray<SCIDownloadJob *> *)history {
    __block NSArray *snapshot = nil;
    dispatch_sync(self.stateQueue, ^{
        snapshot = [self.mutableHistory copy];
    });

    return snapshot;
}

// MARK: - Enqueueing

- (SCIDownloadJob *)enqueueURL:(NSURL *)url
                 fileExtension:(NSString *)fileExtension
                   displayName:(NSString *)displayName
                   sourceLabel:(NSString *)sourceLabel {
    if (!url) return nil;

    __block SCIDownloadJob *job = nil;

    dispatch_sync(self.stateQueue, ^{
        // Duplicate detection: an identical URL already in flight is reused rather
        // than downloaded twice.
        for (SCIDownloadJob *existing in self.mutableActive) {
            if ([existing.remoteURL isEqual:url]) {
                job = existing;
                return;
            }
        }

        job = [SCIDownloadJob jobWithURL:url
                           fileExtension:fileExtension
                             displayName:displayName
                             sourceLabel:sourceLabel];

        [self.mutableActive addObject:job];
    });

    [self notifyChangeForJob:job];
    [self pumpQueue];

    return job;
}

- (SCIDownloadJob *)completedJobForURL:(NSURL *)url {
    __block SCIDownloadJob *match = nil;

    dispatch_sync(self.stateQueue, ^{
        for (SCIDownloadJob *job in self.mutableHistory) {
            if (job.state != SCIDownloadStateCompleted) continue;
            if (![job.remoteURL isEqual:url]) continue;

            // Stale entry — the file was cleared from the cache since.
            if (job.localURL && ![[NSFileManager defaultManager] fileExistsAtPath:job.localURL.path]) continue;

            match = job;
            return;
        }
    });

    return match;
}

// MARK: - Scheduling

/// Starts as many queued jobs as the concurrency limit allows.
- (void)pumpQueue {
    NSInteger limit = self.maxConcurrentDownloads;

    dispatch_async(self.stateQueue, ^{
        NSInteger running = 0;
        for (SCIDownloadJob *job in self.mutableActive) {
            if (job.state == SCIDownloadStateDownloading) running++;
        }

        for (SCIDownloadJob *job in self.mutableActive) {
            if (running >= limit) break;
            if (job.state != SCIDownloadStateQueued) continue;

            [self startJobLocked:job];
            running++;
        }
    });
}

/// Must be called on stateQueue.
- (void)startJobLocked:(SCIDownloadJob *)job {
    NSData *resume = self.resumeData[job.identifier];

    NSURLSessionDownloadTask *task = resume
        ? [self.session downloadTaskWithResumeData:resume]
        : [self.session downloadTaskWithURL:job.remoteURL];

    if (!task) {
        job.state = SCIDownloadStateFailed;
        job.failureReason = @"Could not create task";
        [self notifyChangeForJob:job];

        return;
    }

    [self.resumeData removeObjectForKey:job.identifier];
    self.tasks[job.identifier] = task;
    self.throughputSamples[job.identifier] = @[[NSDate date], @(job.bytesReceived)];

    job.state = SCIDownloadStateDownloading;
    [task resume];

    [self notifyChangeForJob:job];
}

// MARK: - Control

- (void)pauseJob:(SCIDownloadJob *)job {
    if (!job || job.state != SCIDownloadStateDownloading) return;

    // Marked paused *before* cancelling: cancellation makes the session fire
    // didCompleteWithError with NSURLErrorCancelled, and that handler needs to
    // already see a paused job so it doesn't record this as a cancellation.
    job.state = SCIDownloadStatePaused;
    job.bytesPerSecond = 0;

    dispatch_async(self.stateQueue, ^{
        NSURLSessionDownloadTask *task = self.tasks[job.identifier];

        if (!task) {
            [self notifyChangeForJob:job];
            return;
        }

        [task cancelByProducingResumeData:^(NSData *data) {
            dispatch_async(self.stateQueue, ^{
                // Without resume data the transfer restarts from zero on resume.
                if (data) self.resumeData[job.identifier] = data;

                [self.tasks removeObjectForKey:job.identifier];

                [self notifyChangeForJob:job];
                [self pumpQueue];
            });
        }];
    });
}

- (void)resumeJob:(SCIDownloadJob *)job {
    if (!job || job.state != SCIDownloadStatePaused) return;

    job.state = SCIDownloadStateQueued;

    [self notifyChangeForJob:job];
    [self pumpQueue];
}

- (void)retryJob:(SCIDownloadJob *)job {
    if (!job) return;

    dispatch_async(self.stateQueue, ^{
        [self.mutableHistory removeObject:job];

        job.attemptCount += 1;
        job.state = SCIDownloadStateQueued;
        job.progress = 0;
        job.bytesReceived = 0;
        job.failureReason = nil;
        job.finishedAt = nil;

        if (![self.mutableActive containsObject:job]) {
            [self.mutableActive addObject:job];
        }

        [self persistHistoryLocked];
    });

    [self notifyChangeForJob:job];
    [self pumpQueue];
}

- (void)cancelJob:(SCIDownloadJob *)job {
    if (!job) return;

    dispatch_async(self.stateQueue, ^{
        [self.tasks[job.identifier] cancel];
        [self.tasks removeObjectForKey:job.identifier];
        [self.resumeData removeObjectForKey:job.identifier];

        [self.mutableActive removeObject:job];

        job.state = SCIDownloadStateCancelled;
        job.finishedAt = [NSDate date];

        [self recordInHistoryLocked:job];
    });

    [self notifyChangeForJob:job];
    [self pumpQueue];
}

- (void)pauseAll {
    for (SCIDownloadJob *job in self.activeJobs) {
        [self pauseJob:job];
    }
}

- (void)resumeAll {
    for (SCIDownloadJob *job in self.activeJobs) {
        [self resumeJob:job];
    }
}

- (void)cancelAll {
    for (SCIDownloadJob *job in self.activeJobs) {
        [self cancelJob:job];
    }
}

// MARK: - History

- (void)removeJobFromHistory:(SCIDownloadJob *)job {
    if (!job) return;

    dispatch_async(self.stateQueue, ^{
        [self.mutableHistory removeObject:job];
        [self persistHistoryLocked];
    });

    [self notifyChangeForJob:nil];
}

- (void)discardJobAndFile:(SCIDownloadJob *)job {
    if (!job) return;

    if (job.localURL) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:job.localURL error:&error];

        if (error) NSLog(@"[Albrhi] Could not delete cached download: %@", error);
    }

    dispatch_async(self.stateQueue, ^{
        [self.mutableHistory removeObject:job];
        [self persistHistoryLocked];
    });

    [self notifyChangeForJob:nil];
}

- (void)clearHistory {
    dispatch_async(self.stateQueue, ^{
        [self.mutableHistory removeAllObjects];
        [self persistHistoryLocked];
    });

    [self notifyChangeForJob:nil];
}

- (int64_t)totalBytesDownloaded {
    __block int64_t total = 0;

    dispatch_sync(self.stateQueue, ^{
        for (SCIDownloadJob *job in self.mutableHistory) {
            if (job.state == SCIDownloadStateCompleted) total += job.bytesReceived;
        }
    });

    return total;
}

/// Must be called on stateQueue.
- (void)recordInHistoryLocked:(SCIDownloadJob *)job {
    [self.mutableHistory insertObject:job atIndex:0];

    while (self.mutableHistory.count > SCIHistoryLimit) {
        [self.mutableHistory removeLastObject];
    }

    [self persistHistoryLocked];
}

- (NSURL *)historyFileURL {
    NSString *dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;

    return [[NSURL fileURLWithPath:dir] URLByAppendingPathComponent:@"albrhi-downloads.plist"];
}

/// Must be called on stateQueue.
- (void)persistHistoryLocked {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[self.mutableHistory copy]
                                        requiringSecureCoding:YES
                                                        error:&error];

    if (!data || error) {
        NSLog(@"[Albrhi] Could not archive download history: %@", error);
        return;
    }

    [data writeToURL:[self historyFileURL] atomically:YES];
}

- (void)loadHistory {
    NSData *data = [NSData dataWithContentsOfURL:[self historyFileURL]];
    if (!data) return;

    NSError *error = nil;
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [SCIDownloadJob class], nil];
    NSArray *jobs = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];

    if (![jobs isKindOfClass:[NSArray class]]) {
        NSLog(@"[Albrhi] Could not read download history: %@", error);
        return;
    }

    [self.mutableHistory addObjectsFromArray:jobs];
}

// MARK: - Notifications

- (void)notifyChangeForJob:(SCIDownloadJob *)job {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCIDownloadQueueDidChangeNotification
                                                            object:self
                                                          userInfo:job ? @{@"job": job} : nil];
    });
}

- (SCIDownloadJob *)jobForTask:(NSURLSessionTask *)task {
    __block SCIDownloadJob *match = nil;

    dispatch_sync(self.stateQueue, ^{
        for (NSString *identifier in self.tasks) {
            if (self.tasks[identifier] != task) continue;

            for (SCIDownloadJob *job in self.mutableActive) {
                if ([job.identifier isEqualToString:identifier]) {
                    match = job;
                    return;
                }
            }
        }
    });

    return match;
}

// MARK: - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    SCIDownloadJob *job = [self jobForTask:downloadTask];
    if (!job) return;

    job.bytesReceived = totalBytesWritten;
    job.bytesExpected = totalBytesExpectedToWrite;
    job.progress = (totalBytesExpectedToWrite > 0)
        ? (float)totalBytesWritten / (float)totalBytesExpectedToWrite
        : 0.0f;

    // Throughput, sampled at most once a second so the label doesn't flicker.
    dispatch_async(self.stateQueue, ^{
        NSArray *sample = self.throughputSamples[job.identifier];
        NSDate *lastDate = sample.firstObject;
        int64_t lastBytes = [sample.lastObject longLongValue];

        NSTimeInterval elapsed = lastDate ? -[lastDate timeIntervalSinceNow] : 0;
        if (elapsed < 1.0) return;

        job.bytesPerSecond = (double)(totalBytesWritten - lastBytes) / elapsed;
        self.throughputSamples[job.identifier] = @[[NSDate date], @(totalBytesWritten)];
    });

    [self notifyChangeForJob:job];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    SCIDownloadJob *job = [self jobForTask:downloadTask];
    if (!job) return;

    // The temp file is deleted the moment this method returns, so move it now —
    // synchronously, on this thread.
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filename = [NSString stringWithFormat:@"%@.%@", job.identifier, job.fileExtension];
    NSURL *destination = [[NSURL fileURLWithPath:cacheDir] URLByAppendingPathComponent:filename];

    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];

    NSError *moveError = nil;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&moveError];

    if (moveError) {
        NSLog(@"[Albrhi] Could not move finished download: %@", moveError);
        job.failureReason = moveError.localizedDescription;
        return;
    }

    job.localURL = destination;
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    SCIDownloadJob *job = [self jobForTask:task];
    if (!job) return;

    // A pause cancels the task too — that is not a failure, and `pauseJob:` has
    // already moved the job to its paused state.
    BOOL pausedByUser = (error.code == NSURLErrorCancelled && job.state == SCIDownloadStatePaused);
    if (pausedByUser) return;

    dispatch_async(self.stateQueue, ^{
        [self.tasks removeObjectForKey:job.identifier];
        [self.throughputSamples removeObjectForKey:job.identifier];
        [self.mutableActive removeObject:job];

        job.finishedAt = [NSDate date];
        job.bytesPerSecond = 0;

        if (error) {
            job.state = (error.code == NSURLErrorCancelled)
                ? SCIDownloadStateCancelled
                : SCIDownloadStateFailed;
            job.failureReason = error.localizedDescription;
        }
        else if (!job.localURL) {
            job.state = SCIDownloadStateFailed;
            if (!job.failureReason) job.failureReason = @"File could not be saved";
        }
        else {
            job.state = SCIDownloadStateCompleted;
            job.progress = 1.0f;
        }

        [self recordInHistoryLocked:job];
    });

    [self notifyChangeForJob:job];
    [self pumpQueue];
}

@end
