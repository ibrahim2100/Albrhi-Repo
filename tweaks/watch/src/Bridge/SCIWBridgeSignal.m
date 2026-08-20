//
//  SCIWBridgeSignal.m
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIWBridgeSignal.h"
#import "../Prefs.h"
#import <notify.h>

static const char *const kSCIWBridgeNotification = "com.albrhi.watch.bridge";

void SCIWBridgeAnnounce(void) {
    // Did our own write survive? The probe has just written `watch_probe_report_com.apple.Bridge`;
    // a synchronise and a read is the only honest way to ask, since CFPreferences reports no error
    // when the sandbox refuses it -- the value simply is not there afterwards.
    CFPreferencesAppSynchronize(SCIWDomain);
    CFPropertyListRef mine = CFPreferencesCopyAppValue(
        CFSTR("watch_probe_report_com.apple.Bridge"), SCIWDomain);

    SCIWBridgeState state = mine ? SCIWBridgeStateWriteWorked : SCIWBridgeStateWriteDenied;
    if (mine) CFRelease(mine);

    int token = 0;
    if (notify_register_check(kSCIWBridgeNotification, &token) != NOTIFY_STATUS_OK) return;

    notify_set_state(token, (uint64_t)state);
    notify_post(kSCIWBridgeNotification);
    notify_cancel(token);

    NSLog(@"[AlbrhiWatch] announced bridge state %llu", (uint64_t)state);
}

void SCIWBridgeListen(void) {
    static int token = 0;

    notify_register_dispatch(kSCIWBridgeNotification, &token, dispatch_get_main_queue(), ^(int t) {
        uint64_t state = 0;
        if (notify_get_state(t, &state) != NOTIFY_STATUS_OK) return;

        NSString *text;
        switch ((SCIWBridgeState)state) {
            case SCIWBridgeStateWriteWorked:
                text = @"the tweak ran in the Watch app and wrote its own report";
                break;
            case SCIWBridgeStateWriteDenied:
                // The interesting one. Everything above still ran; only the report is stuck.
                text = @"the tweak RAN in the Watch app, and its report could not be written — "
                       @"the app is sandboxed and cfprefsd refused the domain. The section below "
                       @"is empty for that reason, not because nothing was injected.";
                break;
            default:
                text = @"the tweak ran in the Watch app";
                break;
        }

        // SpringBoard is not sandboxed, so this write is the one that always lands.
        CFPreferencesSetAppValue(CFSTR("watch_bridge_state"),
                                 (__bridge CFPropertyListRef)text, SCIWDomain);
        CFPreferencesSetAppValue(CFSTR("watch_bridge_stamp"),
                                 (__bridge CFPropertyListRef)[NSDate date].description, SCIWDomain);
        CFPreferencesAppSynchronize(SCIWDomain);
    });
}
