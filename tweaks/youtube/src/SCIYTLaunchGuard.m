#import "SCIYTLaunchGuard.h"
#import "SCILog.h"
#import <UIKit/UIKit.h>
#import <stdatomic.h>

/// Long enough that a cold launch on an old phone with a slow network is never mistaken for a
/// fault, short enough that nobody sits looking at a logo wondering whether to force-quit.
static const NSTimeInterval kSCILaunchBudget = 8.0;

static atomic_bool sciLaunched = false;
static atomic_bool sciStoodDown = false;
static NSTimeInterval sciStartedAt = 0;

///
/// The trail, and why it is written the way it is.
///
/// Appended under a lock because hooks fire on whatever thread the app is using, and rewritten to
/// the report on a short delay rather than on every mark: the point is to survive a launch that
/// dies, and a file written twenty times a second during a hang is a file being written while the
/// thing it describes is stuck.
///
static NSMutableArray<NSString *> *sciTrail = nil;
static NSLock *sciTrailLock = nil;
static NSTimeInterval sciFirstMark = 0;

void SCIYTLaunchMark(NSString *milestone) {
    if (!milestone.length) return;

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sciTrail = [NSMutableArray array];
        sciTrailLock = [[NSLock alloc] init];
        sciFirstMark = [NSDate date].timeIntervalSince1970;
    });

    [sciTrailLock lock];
    BOOL already = [sciTrail containsObject:milestone];
    if (!already) {
        [sciTrail addObject:[NSString stringWithFormat:@"%@ (+%.1fs)", milestone,
            [NSDate date].timeIntervalSince1970 - sciFirstMark]];
    }
    [sciTrailLock unlock];

    // Once per milestone, not once per call: several of these are hooks that fire constantly, and
    // what is being recorded is that they fired at all.
    if (already) return;

    // A moment later and off the main thread. The report is written to the app's own container,
    // and the launch this is describing may be the one that is stuck.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [NSClassFromString(@"SCIYTDiagnostics") performSelector:@selector(writeReportToFile)];
    });
}

NSString *SCIYTLaunchTrail(void) {
    if (!sciTrail) return @"nothing marked — the tweak did not reach its first milestone";

    [sciTrailLock lock];
    NSString *trail = [sciTrail componentsJoinedByString:@" → "];
    [sciTrailLock unlock];
    return trail;
}

BOOL SCIYTStoodDown(void) {
    return atomic_load_explicit(&sciStoodDown, memory_order_relaxed);
}

NSString *SCIYTLaunchGuardReport(void) {
    if (SCIYTStoodDown()) {
        return [NSString stringWithFormat:
            @"launch guard: TRIPPED — the app had not become active %.0f seconds after this "
            @"tweak loaded, so everything expensive stood down for this session. The app you are "
            @"using is close to stock. Report this: it is a fault in the tweak, not in your phone.",
            kSCILaunchBudget];
    }

    if (atomic_load_explicit(&sciLaunched, memory_order_relaxed)) {
        return @"launch guard: the app became active in time; nothing stood down";
    }

    return @"launch guard: watching — the app has not reported itself active yet";
}

BOOL SCIYTAppIsActive(void) {
    return atomic_load_explicit(&sciLaunched, memory_order_relaxed);
}

/// Blocks waiting for the app to be active, and the observer that drains them.
///
/// A plain notification observer per caller would do the same thing; this exists so the queue can
/// be drained exactly once and on the main thread, since what waits here changes views.
static NSMutableArray<void (^)(void)> *sciWaiting = nil;

void SCIYTWhenActive(void (^block)(void)) {
    if (!block) return;

    if (SCIYTAppIsActive()) {
        dispatch_async(dispatch_get_main_queue(), block);
        return;
    }

    static dispatch_once_t once;
    dispatch_once(&once, ^{ sciWaiting = [NSMutableArray array]; });

    @synchronized (sciWaiting) { [sciWaiting addObject:[block copy]]; }
}

static void SCIDrainWaiting(void) {
    NSArray<void (^)(void)> *blocks = nil;
    if (!sciWaiting) return;

    @synchronized (sciWaiting) {
        blocks = [sciWaiting copy];
        [sciWaiting removeAllObjects];
    }

    // A turn later, on purpose: `didBecomeActive` is delivered while UIKit is still finishing
    // the transition, and the point of waiting at all was to be out of the way.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        for (void (^block)(void) in blocks) block();
    });
}

void SCIYTLaunchGuardStart(void) {
    sciStartedAt = [NSDate date].timeIntervalSince1970;

    // Either notification counts. `didBecomeActive` is the one that means a person is looking at
    // the app; `didFinishLaunching` is the one that arrives even when it is launched into the
    // background, and treating that as a failure would stand the tweak down for a launch that was
    // never going to show anything.
    for (NSNotificationName name in @[UIApplicationDidBecomeActiveNotification,
                                      UIApplicationDidFinishLaunchingNotification]) {
        [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(__unused NSNotification *note) {
            atomic_store_explicit(&sciLaunched, true, memory_order_relaxed);
            SCIDrainWaiting();
        }];
    }

    // A background queue on purpose: the case this exists for is a main thread that is not
    // getting anywhere, and a main-queue timer would be waiting behind exactly that.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCILaunchBudget * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (atomic_load_explicit(&sciLaunched, memory_order_relaxed)) return;

        atomic_store_explicit(&sciStoodDown, true, memory_order_relaxed);
        NSLog(@"[AlbrhiYT] launch guard tripped after %.0fs — standing every hook down",
              kSCILaunchBudget);

        // Written down as well as logged. A log line is gone when the phone reboots and cannot be
        // read from a settings screen; the report is a file, and it is the only evidence a launch
        // that never finished leaves behind.
        SCIYTLaunchMark(@"launch guard TRIPPED");
    });
}
