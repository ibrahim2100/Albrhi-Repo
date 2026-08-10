#import <Foundation/Foundation.h>

///
/// Logging, off unless the verbose_logging preference is on.
///
/// A copy of the other tweaks' rather than a shared header, for the reason written in
/// YouTube's: nothing moves into shared/ until a second consumer needs it and the shape it
/// needs is known. Three copies of four lines is cheaper than a shared header that has to
/// be right for three apps at once.
///
static inline BOOL SCIVerboseLogging(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"verbose_logging"];
}

#define SCILogV(fmt, ...)                                                    \
    do {                                                                     \
        if (SCIVerboseLogging()) {                                           \
            NSLog(@"[AlbrhiTW] " fmt, ##__VA_ARGS__);                        \
        }                                                                    \
    } while (0)
