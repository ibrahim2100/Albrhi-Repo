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
    });
}
