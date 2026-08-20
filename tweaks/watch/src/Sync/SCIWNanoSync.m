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
static NSArray<NSString *> *SCIWCandidateDomains(void) {
    return @[
        // Photos
        @"com.apple.NanoPhotos", @"com.apple.mobileslideshow", @"com.apple.nanophotos",
        // Music
        @"com.apple.NanoMusic", @"com.apple.Music", @"com.apple.nanomusic",
        // Companion apps
        @"com.apple.NanoAppRegistry", @"com.apple.nanoappregistry", @"com.apple.Carousel",
        // Maps
        @"com.apple.NanoMaps", @"com.apple.Maps", @"com.apple.nanomaps",
        // The watch's own settings, where a good many of the above are actually recorded
        @"com.apple.NanoSettings", @"com.apple.nanosettings",
        @"com.apple.nanosystemsettings", @"com.apple.Bridge",
    ];
}

static NSString *SCIWDescribeDomain(Class accessorClass, NSString *domain) {
    id accessor = [accessorClass alloc];
    if (![accessor respondsToSelector:@selector(initWithDomain:)]) return nil;

    accessor = ((id (*)(id, SEL, id))objc_msgSend)(accessor, @selector(initWithDomain:), domain);
    if (!accessor) return [NSString stringWithFormat:@"%@ — no accessor", domain];

    unsigned long long size = [accessor respondsToSelector:@selector(domainSize)]
        ? ((unsigned long long (*)(id, SEL))objc_msgSend)(accessor, @selector(domainSize)) : 0;

    id keys = [accessor respondsToSelector:@selector(copyKeyList)]
        ? ((id (*)(id, SEL))objc_msgSend)(accessor, @selector(copyKeyList)) : nil;

    if ([accessor respondsToSelector:@selector(invalidate)]) {
        ((void (*)(id, SEL))objc_msgSend)(accessor, @selector(invalidate));
    }

    if (![keys isKindOfClass:[NSArray class]] || ![keys count]) {
        return [NSString stringWithFormat:@"%@ — %llu byte(s), no keys", domain, size];
    }

    // Sorted, because an unordered list read twice looks like two different lists.
    NSArray *sorted = [keys sortedArrayUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"%@ — %llu byte(s), %lu key(s):\n    %@",
            domain, size, (unsigned long)sorted.count,
            [sorted componentsJoinedByString:@"\n    "]];
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

        for (NSString *domain in SCIWCandidateDomains()) {
            NSString *line = SCIWDescribeDomain(accessorClass, domain);
            if (line) [lines addObject:line];
        }

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
