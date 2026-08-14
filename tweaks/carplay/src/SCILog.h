#import <Foundation/Foundation.h>
#import "shared/src/SCIPanelGate.h"
#import "shared/src/SCICPPrefsKeys.h"

///
/// Logging, off unless the panel's CarPlay settings page has turned it on.
///
/// Read cross-process through SCIPanelReadBool rather than NSUserDefaults: this tweak's
/// preferences are set from Albrhi Panel, which runs inside Settings, not inside
/// SpringBoard or Camera where this macro is actually used.
///
/// Read once and kept, the same way SCIPanelAllowsThisApp caches the on/off switch --
/// this macro fires on every SCILogV call, and asking cfprefsd across the sandbox
/// boundary each time would be a cost paid on every log line for a value that cannot
/// change during this process's life.
static inline BOOL SCIVerboseLogging(void) {
    static BOOL verbose = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        verbose = SCIPanelReadBool(SCICPVerboseLoggingKey, NO);
    });
    return verbose;
}

#define SCILogV(fmt, ...)                                                    \
    do {                                                                     \
        if (SCIVerboseLogging()) {                                           \
            NSLog(@"[AlbrhiCP] " fmt, ##__VA_ARGS__);                        \
        }                                                                    \
    } while (0)
