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
