#import "SCIYTParts.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

/// How many parts are in flight at once.
///
/// Four, and the number is a compromise rather than a maximum. Google serves these happily
/// enough in parallel, but a phone on a weak connection sharing its bandwidth four ways makes
/// each individual part slower and more likely to time out -- and a timeout costs a retry,
/// which costs more than the parallelism saved. Four is the point where the round trips stop
/// dominating without the transfers starting to fight each other.
static const NSUInteger kSCIParallel = 4;

/// How many times one part is asked for before the run gives up.
static const NSUInteger kSCIAttempts = 3;


///
/// One run's state.
///
/// A class rather than captured variables, because several callbacks touch this at once and
/// they need to be looking at the same thing. Every field is read and written on one serial
/// queue, which is what makes "several at a time" safe to reason about at all.
///
@interface SCIYTPartsRun : NSObject
@property (nonatomic, strong) NSArray<NSString *> *addresses;
@property (nonatomic, strong) NSURL *folder;
@property (nonatomic, strong) NSMutableArray<NSURL *> *files;   ///< indexed like addresses
@property (nonatomic, strong) dispatch_queue_t lock;

@property (nonatomic) NSUInteger nextIndex;    ///< the next address to hand out
@property (nonatomic) NSUInteger completed;
@property (nonatomic) NSUInteger inFlight;
@property (nonatomic) BOOL finished;           ///< the completion has been called

@property (nonatomic, copy) void (^progress)(double);
@property (nonatomic, copy) void (^completion)(NSArray<NSURL *> *, NSURL *, NSString *);
@end

@implementation SCIYTPartsRun
@end


@implementation SCIYTParts

+ (NSURLSession *)session {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *configuration =
            [NSURLSessionConfiguration defaultSessionConfiguration];

        // Enough for the parts in flight and no more. Left at the default, iOS would happily
        // open far more than four to one host if anything ever asked it to.
        configuration.HTTPMaximumConnectionsPerHost = kSCIParallel;
        configuration.timeoutIntervalForRequest = 30;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

+ (void)fetch:(NSArray<NSString *> *)addresses
     progress:(void (^)(double))progress
   completion:(void (^)(NSArray<NSURL *> *, NSURL *, NSString *))completion {

    if (!addresses.count) {
        completion(nil, nil, SCILocalized(@"dl_hls_no_segments"));
        return;
    }

    NSURL *folder = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];

    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:folder
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
    if (error) {
        completion(nil, nil, SCILocalized(@"dl_failed"));
        return;
    }

    SCIYTPartsRun *run = [[SCIYTPartsRun alloc] init];
    run.addresses = addresses;
    run.folder = folder;
    run.files = [NSMutableArray arrayWithCapacity:addresses.count];
    run.lock = dispatch_queue_create("com.albrhi.youtube.parts", DISPATCH_QUEUE_SERIAL);
    run.progress = progress;
    run.completion = completion;

    // Filled with placeholders so a part can be written at its own index whenever it lands.
    // This is the ordering guarantee in one line: the slot is decided before the request is
    // made, so arrival order cannot reach it.
    for (NSUInteger i = 0; i < addresses.count; i++) [run.files addObject:(id)[NSNull null]];

    SCILogV(@"parts: fetching %lu, %lu at a time",
            (unsigned long)addresses.count, (unsigned long)kSCIParallel);

    dispatch_async(run.lock, ^{
        for (NSUInteger i = 0; i < MIN(kSCIParallel, addresses.count); i++) {
            [self startNext:run];
        }
    });
}

/// Hands out the next address, if there is one. Called on the run's queue.
+ (void)startNext:(SCIYTPartsRun *)run {
    if (run.finished || run.nextIndex >= run.addresses.count) return;

    NSUInteger index = run.nextIndex;
    run.nextIndex += 1;
    run.inFlight += 1;

    [self fetchOne:run index:index attempt:0];
}

+ (void)fetchOne:(SCIYTPartsRun *)run index:(NSUInteger)index attempt:(NSUInteger)attempt {
    NSURL *url = [NSURL URLWithString:run.addresses[index]];
    if (!url) {
        dispatch_async(run.lock, ^{ [self failRun:run with:SCILocalized(@"dl_failed")]; });
        return;
    }

    [[[self session] dataTaskWithURL:url
                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)response).statusCode : 0;

        // A refusal is not a hiccup: 4xx means the address is wrong or has expired, and
        // asking again three times makes the same mistake more slowly. Anything else is
        // worth another go.
        BOOL worthRetrying = (status < 400 || status >= 500);

        if ((!data.length || error) && worthRetrying && attempt < kSCIAttempts - 1) {
            double pause = 0.5 * (double)(attempt + 1);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pause * NSEC_PER_SEC)),
                           run.lock, ^{
                if (!run.finished) [self fetchOne:run index:index attempt:attempt + 1];
            });
            return;
        }

        if (!data.length || error) {
            dispatch_async(run.lock, ^{
                [SCIYTDiagnostics recordStreamAttempt:
                    [NSString stringWithFormat:@"parts: %lu of %lu failed after %lu tries — %@",
                        (unsigned long)(index + 1), (unsigned long)run.addresses.count,
                        (unsigned long)kSCIAttempts,
                        error.localizedDescription
                            ?: [NSString stringWithFormat:@"HTTP %ld", (long)status]]];

                [self failRun:run with:error.localizedDescription ?: SCILocalized(@"dl_failed")];
            });
            return;
        }

        // Named for its index, zero padded so the join can sort as text and get numbers.
        // Without the padding, part 10 sorts before part 9 and the video is silently wrong.
        NSURL *file = [run.folder URLByAppendingPathComponent:
            [NSString stringWithFormat:@"%06lu.part", (unsigned long)index]];

        if (![data writeToURL:file atomically:YES]) {
            dispatch_async(run.lock, ^{
                [self failRun:run with:SCILocalized(@"dl_ts_write_failed")];
            });
            return;
        }

        dispatch_async(run.lock, ^{
            if (run.finished) return;

            run.files[index] = file;
            run.completed += 1;
            run.inFlight -= 1;

            if (run.progress) {
                double fraction = (double)run.completed / (double)run.addresses.count;
                dispatch_async(dispatch_get_main_queue(), ^{ run.progress(fraction); });
            }

            if (run.completed == run.addresses.count) {
                run.finished = YES;
                NSArray<NSURL *> *ordered = [run.files copy];
                NSURL *folder = run.folder;
                void (^done)(NSArray<NSURL *> *, NSURL *, NSString *) = run.completion;

                dispatch_async(dispatch_get_main_queue(), ^{ done(ordered, folder, nil); });
                return;
            }

            [self startNext:run];
        });
    }] resume];
}

/// Ends the run once, and clears up. Called on the run's queue.
+ (void)failRun:(SCIYTPartsRun *)run with:(NSString *)message {
    if (run.finished) return;
    run.finished = YES;

    [[NSFileManager defaultManager] removeItemAtURL:run.folder error:nil];

    void (^done)(NSArray<NSURL *> *, NSURL *, NSString *) = run.completion;
    dispatch_async(dispatch_get_main_queue(), ^{ done(nil, nil, message); });
}

+ (NSURL *)join:(NSArray<NSURL *> *)ordered
      extension:(NSString *)extension
         folder:(NSURL *)folder {

    NSURL *joined = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension]]];

    [[NSFileManager defaultManager] createFileAtPath:joined.path contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:joined error:nil];

    if (!handle) {
        [[NSFileManager defaultManager] removeItemAtURL:folder error:nil];
        return nil;
    }

    BOOL ok = YES;
    for (NSURL *file in ordered) {
        // Mapped rather than read: one part at a time is a few megabytes, and mapping lets
        // the system page it rather than the process holding it.
        NSData *part = [NSData dataWithContentsOfURL:file
                                             options:NSDataReadingMappedIfSafe
                                               error:nil];
        if (!part.length) { ok = NO; break; }

        @try {
            [handle writeData:part];
        } @catch (NSException *exception) {
            SCILogV(@"parts: could not write — %@", exception.reason);
            ok = NO;
            break;
        }
    }

    [handle closeFile];
    [[NSFileManager defaultManager] removeItemAtURL:folder error:nil];

    if (!ok) {
        [[NSFileManager defaultManager] removeItemAtURL:joined error:nil];
        return nil;
    }

    return joined;
}

@end
