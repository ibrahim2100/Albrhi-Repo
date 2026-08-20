//
//  SCIWNanoSync.m
//  Albrhi Watch
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIWNanoSync.h"
#import "../Prefs.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *sciwNanoReport = nil;

///
/// The domains worth asking about, and why each one is here.
///
/// Every name is a guess **and is treated as one** — the point of the probe is that the device
/// answers, so a domain that does not exist costs one line saying so rather than a feature written
/// against it. The four the owner asked for are photos, music, companion apps and Maps, so both
/// spellings of each are tried: the `Nano*` name the watch side tends to use, and the phone app's
/// own bundle identifier, which is what `-synchronizeUserDefaultsDomain:` takes.
///
///
/// The domains this device actually has, read out of the paired watch's own registry.
///
/// **Sixteen guessed names all answered zero while the accessor reported itself bound with a real
/// pairing ID**, which is a broken measurement rather than an empty world. The registry answered
/// instead: `/var/mobile/Library/DeviceRegistry/<pairingID>/` lists `NanoPhotos`, `NanoMaps`,
/// `NanoAppRegistry`, `NanoSystemSettings`, `com.apple.carousel` and a dozen more — **and not one
/// of the guesses was among them in that form.**
///
/// Two directories are read: the registry root, whose entries are the subsystems, and
/// `NanoPreferencesSync/NanoDomains`, which is where a synced *preference* domain would keep its
/// file. A `.plist` suffix is stripped, because a domain is `com.apple.NanoMaps` and the file is
/// `com.apple.NanoMaps.plist` — the name and its storage are not the same string, and this project
/// has already spent a release on treating one as the other.
///
static NSArray<NSString *> *SCIWDiscoveredDomains(NSString *pairingID) {
    if (!pairingID.length) return @[];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *registry = [NSString stringWithFormat:
        @"/var/mobile/Library/DeviceRegistry/%@", pairingID];

    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];

    for (NSString *directory in @[[registry stringByAppendingPathComponent:
                                      @"NanoPreferencesSync/NanoDomains"],
                                  [registry stringByAppendingPathComponent:
                                      @"NanoPreferencesSync/Backup"],
                                  registry]) {
        for (NSString *entry in [fm contentsOfDirectoryAtPath:directory error:NULL]) {
            NSString *name = [entry.pathExtension isEqualToString:@"plist"]
                ? entry.stringByDeletingPathExtension : entry;

            // The registry root also holds `NanoPreferencesSync` itself and a `.db`; neither is a
            // domain, and asking about them would put two lines of noise at the top of the answer.
            if ([name isEqualToString:@"NanoPreferencesSync"]) continue;
            if (entry.pathExtension.length && ![entry.pathExtension isEqualToString:@"plist"])
                continue;

            [names addObject:name];
        }
    }

    return names.array;
}

///
/// The names that were *guessed*, kept only as the control group.
///
/// They all answer zero, and that is the point: a report that shows the guesses beside the read
/// names is a report that shows why reading is not optional. Four are kept rather than sixteen —
/// the finding is established, and sixteen lines of it is a report nobody finishes.
///
static NSArray<NSString *> *SCIWCandidateDomains(void) {
    return @[
        @"com.apple.NanoPhotos", @"com.apple.NanoMusic",
        @"com.apple.NanoMaps", @"com.apple.Bridge",
    ];
}

///
/// **Sixteen domains answering zero is one answer, not sixteen.**
///
/// The first probe reported `0 byte(s), no keys` for every candidate — including
/// `com.apple.Bridge`, which the Watch app plainly uses. A uniform zero across unrelated things is
/// the signature of a broken measurement, not of an empty world; this project has met it before,
/// when every bitrate entry scored zero because the selector name was wrong on every one of them.
///
/// The class says what to ask. It declares `-initializedWithActiveDevice`, `-shouldNotDoWork`,
/// `-pairingID` and `-activeDeviceChanged` — an accessor built with the plain `-initWithDomain:`
/// may simply not be bound to a paired watch, in which case it answers about nothing rather than
/// failing. So liveness is reported beside the size, and the size stops being read as a fact about
/// the domain.
///
static NSString *SCIWAccessorLiveness(id accessor) {
    NSMutableArray<NSString *> *notes = [NSMutableArray array];

    if ([accessor respondsToSelector:@selector(initializedWithActiveDevice)]) {
        BOOL live = ((BOOL (*)(id, SEL))objc_msgSend)(accessor,
                        @selector(initializedWithActiveDevice));
        [notes addObject:live ? @"bound to the active device" : @"NOT bound to an active device"];
    }

    if ([accessor respondsToSelector:@selector(shouldNotDoWork)]) {
        id stop = ((id (*)(id, SEL))objc_msgSend)(accessor, @selector(shouldNotDoWork));
        if (stop) [notes addObject:[NSString stringWithFormat:@"shouldNotDoWork = %@", stop]];
    }

    if ([accessor respondsToSelector:@selector(pairingID)]) {
        id pairing = ((id (*)(id, SEL))objc_msgSend)(accessor, @selector(pairingID));
        [notes addObject:[NSString stringWithFormat:@"pairingID = %@", pairing ?: @"(none)"]];
    }

    if ([accessor respondsToSelector:@selector(requiresDeviceUnlockedSinceBoot)]) {
        BOOL needsUnlock = ((BOOL (*)(id, SEL))objc_msgSend)(accessor,
                               @selector(requiresDeviceUnlockedSinceBoot));
        if (needsUnlock) [notes addObject:@"requires the device unlocked since boot"];
    }

    return notes.count ? [notes componentsJoinedByString:@", "] : @"answers nothing about itself";
}

static NSString *SCIWDescribeDomain(Class accessorClass, NSString *domain, BOOL withLiveness) {
    id accessor = [accessorClass alloc];
    if (![accessor respondsToSelector:@selector(initWithDomain:)]) return nil;

    accessor = ((id (*)(id, SEL, id))objc_msgSend)(accessor, @selector(initWithDomain:), domain);
    if (!accessor) return [NSString stringWithFormat:@"%@ — no accessor", domain];

    // Asked of the first domain only: it is a fact about the accessor, not about the domain, so
    // sixteen copies of it would be sixteen copies of one line.
    NSString *liveness = withLiveness ? SCIWAccessorLiveness(accessor) : nil;

    unsigned long long size = [accessor respondsToSelector:@selector(domainSize)]
        ? ((unsigned long long (*)(id, SEL))objc_msgSend)(accessor, @selector(domainSize)) : 0;

    id keys = [accessor respondsToSelector:@selector(copyKeyList)]
        ? ((id (*)(id, SEL))objc_msgSend)(accessor, @selector(copyKeyList)) : nil;

    if ([accessor respondsToSelector:@selector(invalidate)]) {
        ((void (*)(id, SEL))objc_msgSend)(accessor, @selector(invalidate));
    }

    if (![keys isKindOfClass:[NSArray class]] || ![keys count]) {
        return [NSString stringWithFormat:@"%@ — %llu byte(s), no keys%@", domain, size,
                liveness.length ? [@"\n    accessor: " stringByAppendingString:liveness] : @""];
    }

    // Sorted, because an unordered list read twice looks like two different lists.
    NSArray *sorted = [keys sortedArrayUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"%@ — %llu byte(s), %lu key(s):\n    %@%@",
            domain, size, (unsigned long)sorted.count,
            [sorted componentsJoinedByString:@"\n    "],
            liveness.length ? [@"\n    accessor: " stringByAppendingString:liveness] : @""];
}

///
/// **The accessor is bound and every domain is empty, so the names are wrong — and names are the
/// one thing a device can be asked for instead of guessed at.**
///
/// The probe answered `bound to the active device, pairingID = 53DE7DDA-…` and then reported
/// nothing in all sixteen candidates. A live accessor over an empty domain means the domain does
/// not exist under that name, and sixteen guesses are sixteen guesses however carefully chosen.
///
/// NanoPreferencesSync keeps a watch's synced domains **on disk**, under the paired device's own
/// registry directory, one file per domain. SpringBoard is not sandboxed, so the directory can
/// simply be listed — and the file names *are* the domain names. This is the same move as dumping
/// a class's method list instead of trying selectors: stop proposing names, read them.
///
static NSString *SCIWListRegistry(NSString *pairingID) {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSMutableArray<NSString *> *roots = [NSMutableArray arrayWithArray:@[
        @"/var/mobile/Library/DeviceRegistry",
        @"/var/mobile/Library/NanoPreferencesSync",
    ]];

    if (pairingID.length) {
        [roots addObject:[NSString stringWithFormat:
            @"/var/mobile/Library/DeviceRegistry/%@", pairingID]];
        [roots addObject:[NSString stringWithFormat:
            @"/var/mobile/Library/DeviceRegistry/%@/NanoPreferencesSync", pairingID]];
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    for (NSString *root in roots) {
        NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:root error:NULL];
        if (!entries) {
            [lines addObject:[NSString stringWithFormat:@"%@ — not readable or not there", root]];
            continue;
        }

        NSArray *sorted = [entries sortedArrayUsingSelector:@selector(compare:)];
        [lines addObject:[NSString stringWithFormat:@"%@ — %lu entr(ies):\n    %@", root,
                          (unsigned long)sorted.count,
                          [sorted componentsJoinedByString:@"\n    "]]];
    }

    return [lines componentsJoinedByString:@"\n"];
}

static NSString *SCIWActivePairingID(Class accessorClass) {
    id accessor = ((id (*)(id, SEL, id))objc_msgSend)([accessorClass alloc],
                      @selector(initWithDomain:), @"com.apple.Bridge");

    if (![accessor respondsToSelector:@selector(pairingID)]) return nil;

    id pairing = ((id (*)(id, SEL))objc_msgSend)(accessor, @selector(pairingID));
    return [pairing isKindOfClass:[NSString class]] ? pairing : [pairing description];
}

void SCIWRunNanoProbe(void) {
    Class accessorClass = NSClassFromString(@"NPSDomainAccessor");
    if (!accessorClass) {
        sciwNanoReport = @"NPSDomainAccessor is not in this process";
        return;
    }

    //
    // **Off the main thread, and after the launch it would otherwise be part of.**
    //
    // Every one of these calls goes to a daemon over XPC, and this runs inside SpringBoard: a
    // diagnostic that stalls the home screen while a paired-device query times out is worse than
    // no diagnostic. This project has already paid once for a hook whose cost was never measured.
    //
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSString *> *lines = [NSMutableArray array];

        NSString *pairingID = SCIWActivePairingID(accessorClass);
        NSArray<NSString *> *discovered = SCIWDiscoveredDomains(pairingID);

        [lines addObject:[NSString stringWithFormat:
            @"read from the registry — %lu name(s):", (unsigned long)discovered.count]];

        BOOL first = YES;
        for (NSString *domain in discovered) {
            NSString *line = SCIWDescribeDomain(accessorClass, domain, first);
            if (line) [lines addObject:line];
            first = NO;
        }

        // The control group. Kept short and kept last: it is the evidence that reading the names
        // was not optional, not a list anybody needs to act on.
        [lines addObject:@"\nguessed, for comparison:"];
        for (NSString *domain in SCIWCandidateDomains()) {
            NSString *line = SCIWDescribeDomain(accessorClass, domain, NO);
            if (line) [lines addObject:line];
        }

        // The names, read rather than proposed. Printed after the candidates so the two can be
        // compared in one glance: what was guessed, and what is actually there.
        [lines addObject:@"\nwhere the domains actually live:"];
        [lines addObject:SCIWListRegistry(pairingID)];

        sciwNanoReport = [lines componentsJoinedByString:@"\n"];

        // SpringBoard is not sandboxed, so this write lands where Settings can read it.
        CFPreferencesSetAppValue(CFSTR("watch_nano_report"),
                                 (__bridge CFPropertyListRef)sciwNanoReport, SCIWDomain);
        CFPreferencesAppSynchronize(SCIWDomain);
    });
}

NSString *SCIWNanoProbeReport(void) {
    return sciwNanoReport ?: @"the domain probe has not finished yet";
}
