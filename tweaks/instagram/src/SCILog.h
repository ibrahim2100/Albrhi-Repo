#import <Foundation/Foundation.h>

///
/// Gated logging.
///
/// Silent unless the user turns on verbose logging in Settings → Debug, so a
/// release build doesn't narrate every layout pass and gesture into the system log.
///
/// Deliberately standalone: Utils.h pulls in InstagramHeaders and JGProgressHUD, and
/// the downloader and settings layers have no business importing either just to
/// write a log line.
///

#define SCILogV(fmt, ...) \
    do { \
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"verbose_logging"]) { \
            NSLog((fmt), ##__VA_ARGS__); \
        } \
    } while (0)
