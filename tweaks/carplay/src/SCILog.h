#import <Foundation/Foundation.h>

///
/// Logging, off unless the verbose_logging preference is on.
///
/// A copy of the other tweaks' rather than a shared header, for the reason written in the
/// others': nothing moves into shared/ until a second consumer needs it and the shape it
/// needs is known.
///
static inline BOOL SCIVerboseLogging(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"verbose_logging"];
}

#define SCILogV(fmt, ...)                                                    \
    do {                                                                     \
        if (SCIVerboseLogging()) {                                           \
            NSLog(@"[AlbrhiCP] " fmt, ##__VA_ARGS__);                        \
        }                                                                    \
    } while (0)
