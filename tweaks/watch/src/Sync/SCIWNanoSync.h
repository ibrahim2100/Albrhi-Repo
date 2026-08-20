//
//  SCIWNanoSync.h
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

///
/// NanoPreferencesSync, asked what it actually holds.
///
/// **This is the route the four sync features have to be written from, and the method lists are
/// what settled it.** `NPSManager` offers `-synchronizeNanoDomain:keys:` and
/// `-synchronizeUserDefaultsDomain:keys:container:appGroupContainer:cloudEnabled:`;
/// `NPSDomainAccessor` offers `-initWithDomain:`, typed getters and setters for every plist type,
/// and — the two that matter here — `-copyKeyList` and `-domainSize`. So the phone can read and
/// write the preference domains it syncs to the watch, from SpringBoard, where this tweak already
/// runs. No IDS, no injection into a system app, nothing installed on the watch.
///
/// **What is not known is which domain and which key**, and that is exactly the gap this project
/// has lost releases to before — a name that exists somewhere is not a name that answers here.
/// So nothing is written. A list of candidate domains is opened read-only and asked for its size
/// and its key list, and the report carries the answer. The features get written against key names
/// a device printed.
///
/// Read-only on purpose, and the ordering is deliberate: a `-setObject:forKey:` on a domain that
/// syncs to a watch is not a diagnostic, it is a change to a paired device.
///
void SCIWRunNanoProbe(void);

/// What the probe found, or why it did not run.
NSString *SCIWNanoProbeReport(void);
