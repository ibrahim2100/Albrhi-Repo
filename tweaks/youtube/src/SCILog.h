#import <Foundation/Foundation.h>

///
/// Logging, off unless the verbose_logging preference is on.
///
/// Deliberately a copy of Instagram's rather than a shared header. Nothing is
/// promoted into shared/ until a second tweak genuinely needs it and the shape it
/// needs is known; extracting "shared code" from one consumer is guessing at the
/// interface, and the cost of guessing wrong is coupling two tweaks that have no
/// reason to be coupled.
///
static inline BOOL SCIVerboseLogging(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"verbose_logging"];
}

#define SCILogV(fmt, ...)                                                    \
    do {                                                                     \
        if (SCIVerboseLogging()) {                                           \
            NSLog(@"[AlbrhiYT] " fmt, ##__VA_ARGS__);                        \
        }                                                                    \
    } while (0)
