//
//  SCIWBridgeSignal.m
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIWBridgeSignal.h"
#import "../Prefs.h"
#import "../Update/SCIWUpdateProbe.h"
#import "../Update/SCIWUpdateGuard.h"
#import <notify.h>

static const char *const kSCIWBridgeNotification = "com.albrhi.watch.bridge";

/// The file the Watch app leaves in its own container, and the one thing about this that is
/// certain: **a sandboxed app may always write inside its own container, and an unsandboxed
/// process may always read it.** The direction is what makes it work.
static NSString *const kSCIWDropName = @"AlbrhiWatch-report.txt";

/// Where iOS keeps application containers. Enumerated rather than derived: the directory under it
/// is a UUID assigned at install time, and nothing this code could compute would name it.
static NSString *const kSCIWContainers = @"/var/mobile/Containers/Data/Application";

/// Separates the two things the drop carries. **The update hold's verdict cannot travel by
/// preference either** -- it is written by the same sandboxed process whose write is redirected,
/// which is why "no verdict" was reported by a build that had computed one. One file, one marker,
/// and SpringBoard splits it.
static NSString *const kSCIWGuardMarker = @"\n##GUARD##\n";

void SCIWBridgeAnnounce(void) {
    //
    // **Reading your own write back proved nothing, and a device is what showed it.**
    //
    // The previous release wrote the report into the shared preference domain, read it back, and
    // announced success -- and Settings still saw nothing. Both halves were true: cfprefsd did not
    // refuse the write, it **redirected** it into this app's own container, where the read-back
    // found it exactly where it had been put. A self-verifying write verifies the wrong thing when
    // the failure is redirection rather than refusal, which is a sharper version of this project's
    // own rule about a sandboxed process being answered with nothing rather than an error.
    //
    // So the report travels as a file instead, and the direction is chosen so that neither side
    // needs a permission it does not already have: this app writes inside its own container, which
    // a sandbox always allows, and SpringBoard -- which is not sandboxed -- reads it.
    //
    NSString *drop = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"]
                         stringByAppendingPathComponent:kSCIWDropName];

    NSError *error = nil;
    //
    // **The switches travel with the report, because "not reached" had two meanings.**
    //
    // A verdict of "the Watch app has not run this build" is also what a switched-off tweak
    // produces, and a reader cannot tell those apart -- the same ambiguity the empty section had
    // before the announcement existed. The gate says its own state here so the next report is read
    // once rather than guessed at twice.
    //
    NSString *switches = [NSString stringWithFormat:@"master %@, hold updates %@",
                          SCIWReadPreference(SCIWPrefEnabled, NO) ? @"ON" : @"OFF",
                          SCIWReadPreference(SCIWPrefHoldUpdates, YES) ? @"ON" : @"OFF"];

    NSString *payload = [NSString stringWithFormat:@"%@%@%@\n(%@)",
                         SCIWUpdateProbeReport(), kSCIWGuardMarker, SCIWUpdateGuardReport(),
                         switches];

    BOOL wrote = [payload writeToFile:drop
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:&error];

    int token = 0;
    if (notify_register_check(kSCIWBridgeNotification, &token) != NOTIFY_STATUS_OK) return;

    notify_set_state(token, wrote ? SCIWBridgeStateWriteWorked : SCIWBridgeStateWriteDenied);
    notify_post(kSCIWBridgeNotification);
    notify_cancel(token);

    NSLog(@"[AlbrhiWatch] left report at %@ (%@)", drop, wrote ? @"ok" : error);
}

///
/// Finds what the Watch app left behind.
///
/// The container is a UUID assigned at install time, so it is searched for rather than computed --
/// by a file name no other package uses, taking the newest if a stale container survives an
/// upgrade. SpringBoard runs as `mobile`, which owns every one of these directories.
///
static NSString *SCIWHarvestDroppedReport(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *containers = [fm contentsOfDirectoryAtPath:kSCIWContainers error:NULL];

    NSString *best = nil;
    NSDate *bestDate = nil;

    for (NSString *container in containers) {
        NSString *path = [[[kSCIWContainers stringByAppendingPathComponent:container]
                              stringByAppendingPathComponent:@"Library/Caches"]
                              stringByAppendingPathComponent:kSCIWDropName];

        NSDictionary *attributes = [fm attributesOfItemAtPath:path error:NULL];
        if (!attributes) continue;

        NSDate *modified = attributes[NSFileModificationDate];
        if (!bestDate || [modified compare:bestDate] == NSOrderedDescending) {
            bestDate = modified;
            best = path;
        }
    }

    return best ? [NSString stringWithContentsOfFile:best
                                            encoding:NSUTF8StringEncoding
                                               error:NULL] : nil;
}

void SCIWBridgeListen(void) {
    static int token = 0;

    notify_register_dispatch(kSCIWBridgeNotification, &token, dispatch_get_main_queue(), ^(int t) {
        uint64_t state = 0;
        notify_get_state(t, &state);

        NSString *report = SCIWHarvestDroppedReport();
        NSString *text;

        if (report.length) {
            NSArray<NSString *> *halves = [report componentsSeparatedByString:kSCIWGuardMarker];

            // The whole point: these writes are SpringBoard's, and SpringBoard is not sandboxed.
            CFPreferencesSetAppValue(CFSTR("watch_probe_report_com.apple.Bridge"),
                                     (__bridge CFPropertyListRef)halves.firstObject, SCIWDomain);
            if (halves.count > 1)
                CFPreferencesSetAppValue(CFSTR("watch_update_guard"),
                                         (__bridge CFPropertyListRef)halves.lastObject, SCIWDomain);
            text = @"the tweak ran in the Watch app, and its report was carried over";
        } else if ((SCIWBridgeState)state == SCIWBridgeStateWriteDenied) {
            text = @"the tweak ran in the Watch app but could not write its report at all — "
                   @"not even inside its own container, which should never be refused";
        } else {
            text = @"the tweak ran in the Watch app and left a report, and nothing was found "
                   @"where it should be — the container search came back empty";
        }

        CFPreferencesSetAppValue(CFSTR("watch_bridge_state"),
                                 (__bridge CFPropertyListRef)text, SCIWDomain);
        CFPreferencesSetAppValue(CFSTR("watch_bridge_stamp"),
                                 (__bridge CFPropertyListRef)[NSDate date].description, SCIWDomain);
        CFPreferencesAppSynchronize(SCIWDomain);
    });
}
