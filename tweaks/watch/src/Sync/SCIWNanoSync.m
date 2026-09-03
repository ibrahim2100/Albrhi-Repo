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
            //
            // **`-pathExtension` on a bundle identifier is not an extension, and this dropped the
            // very names most likely to be right.**
            //
            // `com.apple.carousel` answers `carousel`, `com.apple.sharing` answers `sharing` — so
            // a filter that skipped anything with a non-plist extension skipped every domain named
            // like a bundle, which is what an NPS domain looks like. The registry listing had them
            // in plain sight (`com.apple.carousel`, `com.apple.shortcuts`, `com.apple.sharing`)
            // and the report showed sixteen names with none of them in it.
            //
            // Only a literal `.plist` suffix is removed now, and only the database's own three
            // files are skipped by name. A rule written against a *shape* of string ("has an
            // extension") when the real rule is about one exact suffix is the same mistake as
            // matching a localised button title.
            //
            NSString *name = [entry hasSuffix:@".plist"]
                ? [entry substringToIndex:entry.length - 6] : entry;

            if ([name isEqualToString:@"NanoPreferencesSync"]) continue;
            if ([name hasPrefix:@"database.db"]) continue;

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

///
/// The active watch, for the accessor that takes one.
///
/// **Every real domain name still answered zero, which says the accessor and not the name.**
/// `NPSDomainAccessor` offers `-initWithDomain:pairedDevice:` beside the plain `-initWithDomain:`,
/// and an accessor built without a device may be reading the phone's own empty side of a domain
/// whose contents belong to the watch. So both are built and both are reported, and whichever
/// answers is the one the sync features will use.
///
/// The registry's class methods are not in `class_copyMethodList` -- that lists instance methods --
/// so the three plausible accessors are tried by name against the class object itself, and the one
/// that answers is named in the report rather than assumed.
///
static id SCIWActivePairedDevice(void) {
    Class registry = NSClassFromString(@"NRPairedDeviceRegistry");
    if (!registry) return nil;

    for (NSString *name in @[@"sharedInstance", @"defaultRegistry", @"registry"]) {
        SEL selector = NSSelectorFromString(name);
        if (![registry respondsToSelector:selector]) continue;

        id shared = ((id (*)(id, SEL))objc_msgSend)(registry, selector);
        if (![shared respondsToSelector:@selector(getActivePairedDevice)]) continue;

        return ((id (*)(id, SEL))objc_msgSend)(shared, @selector(getActivePairedDevice));
    }
    return nil;
}

static unsigned long long SCIWDomainSize(id accessor) {
    return [accessor respondsToSelector:@selector(domainSize)]
        ? ((unsigned long long (*)(id, SEL))objc_msgSend)(accessor, @selector(domainSize)) : 0;
}

static NSString *SCIWDescribeDomain(Class accessorClass, NSString *domain, BOOL withLiveness) {
    id accessor = [accessorClass alloc];
    if (![accessor respondsToSelector:@selector(initWithDomain:)]) return nil;

    accessor = ((id (*)(id, SEL, id))objc_msgSend)(accessor, @selector(initWithDomain:), domain);
    if (!accessor) return [NSString stringWithFormat:@"%@ — no accessor", domain];

    // The same domain, opened against the watch itself. Reported beside the plain one so the
    // difference is visible rather than inferred -- the whole reason the first probe's uniform
    // zeroes were unreadable is that there was nothing to compare them against.
    NSString *paired = @"";
    id device = SCIWActivePairedDevice();
    if (device) {
        id withDevice = [accessorClass alloc];
        if ([withDevice respondsToSelector:@selector(initWithDomain:pairedDevice:)]) {
            withDevice = ((id (*)(id, SEL, id, id))objc_msgSend)(
                withDevice, @selector(initWithDomain:pairedDevice:), domain, device);

            unsigned long long size = SCIWDomainSize(withDevice);
            id keys = [withDevice respondsToSelector:@selector(copyKeyList)]
                ? ((id (*)(id, SEL))objc_msgSend)(withDevice, @selector(copyKeyList)) : nil;

            //
            // **This is where SpringBoard died, and the check that was missing is one the branch
            // ten lines above already had.**
            //
            // `-count` and `-sortedArrayUsingSelector:` were sent to whatever `-copyKeyList`
            // returned, on the strength of its name. The plain-accessor branch asks
            // `isKindOfClass:` first; this one, written an hour later, did not — and an
            // unrecognised selector in SpringBoard is not a failed diagnostic, it is safe mode.
            //
            // Two branches doing the same job, one of them guarded: exactly the shape CLAUDE.md
            // already records about a derivation existing twice with only one copy correct.
            //
            NSArray *keyList = [keys isKindOfClass:[NSArray class]] ? keys : nil;

            paired = [NSString stringWithFormat:
                          @" | with the paired device: %llu byte(s), %lu key(s)%@",
                      size, (unsigned long)keyList.count,
                      keyList.count ? [@"\n    " stringByAppendingString:
                          [[keyList sortedArrayUsingSelector:@selector(compare:)]
                              componentsJoinedByString:@"\n    "]] : @""];

            if ([withDevice respondsToSelector:@selector(invalidate)])
                ((void (*)(id, SEL))objc_msgSend)(withDevice, @selector(invalidate));
        }
    } else {
        paired = @" | no active paired device from the registry";
    }

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
        return [NSString stringWithFormat:@"%@ — %llu byte(s), no keys%@%@", domain, size, paired,
                liveness.length ? [@"\n    accessor: " stringByAppendingString:liveness] : @""];
    }

    // Sorted, because an unordered list read twice looks like two different lists.
    NSArray *sorted = [keys sortedArrayUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"%@ — %llu byte(s), %lu key(s):\n    %@%@%@",
            domain, size, (unsigned long)sorted.count,
            [sorted componentsJoinedByString:@"\n    "], paired,
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
    //
    // **Off unless it is asked for, and that is a rule this diagnostic earned the hard way.**
    //
    // 0.5.1 put SpringBoard into safe mode. The cause was one missing `isKindOfClass:` and it is
    // fixed above -- but the shape of the risk is not: this probe sends messages to private
    // classes, in the process that draws the home screen, to answer a question nobody has while
    // they are simply using their phone. A feature that fails takes its feature down; a diagnostic
    // that fails here takes the device down.
    //
    // So it runs only when somebody turns it on to take a reading, and turns itself off again
    // afterwards is deliberately *not* done -- a switch that resets itself is a switch that lies.
    //
    if (!SCIWReadPreference(SCIWPrefNanoProbe, NO)) {
        sciwNanoReport = @"off — turn on 'Read the watch's domains' in Settings › "
                         @"Albrhi Watch to take a reading";
        return;
    }

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
