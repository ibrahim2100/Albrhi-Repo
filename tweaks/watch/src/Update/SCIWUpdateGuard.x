#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCIWUpdateGuard.h"
#import "../Prefs.h"
#import "../Diagnostics/SCIWDiagnostics.h"

///
/// Holding watchOS updates back, inside the Watch app.
///
/// **Where this came from, and where it did not.** Reading a commercial tweak's package told us
/// one thing worth knowing and it was a negative: its update feature does not hook the phone's
/// update screen at all -- it speaks to the watch over IDS with protobufs. What *is* on the phone
/// is `SUBManager`, from `SoftwareUpdateBridge`, and the Watch app names
/// `COSSoftwareUpdateController` in its own `General.plist` as the Software Update page. Those two
/// facts are the entire basis for this file; no logic was taken from anybody.
///
/// **The hold is coarse and says so.** `-scanForUpdates` and `-checkForSoftwareUpdate:` are how
/// the Watch app goes looking; refusing them means it finds nothing to offer. That stops an update
/// being presented and installed *through the phone*, which is how a watch update normally
/// arrives. It is not a version filter -- filtering on "26 or newer" needs the update descriptor's
/// own API, which is in the dyld shared cache and cannot be read on iOS 16 without extracting a
/// cryptex. The probe beside this file is what will settle that, from the device, in one report.
///
/// **Nothing is installed unless the runtime encoding matches what these hooks were compiled
/// for.** `class_getInstanceMethod` returning non-NULL proves a selector exists and says nothing
/// about its types, and a `%hook` whose argument types are wrong does not fail politely: arguments
/// arrive in the wrong registers. This project crashed one app four times learning that. So the
/// real encoding is read and compared, and a mismatch installs nothing and reports itself.
///

@interface SUBManager : NSObject
@end

static NSString *sciwGuardState = nil;

/// What each hooked selector must encode as. Read from the device by the probe; anything else
/// means Apple changed the method and this build must not touch it.
static NSString *const kSCIWScanEncoding = @"v16@0:8";        // -scanForUpdates
static NSString *const kSCIWCheckEncoding = @"v24@0:8@16";    // -checkForSoftwareUpdate:

///
/// The state, written where Settings can read it.
///
/// It was computed inside the Watch app and shown nowhere -- the one line a fix gets written
/// from, sitting in a process the person reading the report cannot see into.
///
static void SCIWPublishGuardState(void) {
    if (!sciwGuardState.length) return;
    CFPreferencesSetAppValue(CFSTR("watch_update_guard"),
                             (__bridge CFPropertyListRef)sciwGuardState,
                             CFSTR("com.albrhi.watch"));
    CFPreferencesAppSynchronize(CFSTR("com.albrhi.watch"));
}

/// Why a selector was skipped, in the words the next release gets written from: absent, or present
/// with an encoding that is not what these hooks were compiled against.
static NSString *SCIWDescribeSelector(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return [NSString stringWithFormat:@"-%@ is not on this class", selectorName];

    const char *types = method_getTypeEncoding(method);
    return [NSString stringWithFormat:@"-%@ is %s (expected %@)",
            selectorName, types ?: "no encoding", expected];
}

static BOOL SCIWEncodingMatches(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    if (!types) return NO;

    return [expected isEqualToString:[NSString stringWithUTF8String:types]];
}

//
// **Two groups, because the device says this build has one of these methods and not the other.**
//
// `-scanForUpdates` is here, encoding `v16@0:8`, exactly what these hooks were compiled for.
// `-checkForSoftwareUpdate:` is **not on SUBManager in this build at all** -- and a `%hook` on a
// method a class does not declare does not politely do nothing: Logos *adds* it, so the tweak
// would be installing a method Apple's own code never calls and this project would have invented
// an API. One group per selector is what lets the present one install while the absent one is
// skipped, which a single group could not express.
//
%group UpdateHoldScan

%hook SUBManager

- (void)scanForUpdates {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        %orig;
        return;
    }
    // Refused, not delayed: the Watch app asks again on its own schedule, and a hold that only
    // postponed the first ask would look like it worked for an afternoon.
    SCIWRecordAnswer(@"update scan held");
}

%end
%end

%group UpdateHoldCheck

%hook SUBManager

- (void)checkForSoftwareUpdate:(id)completion {
    if (!SCIWPrefEnabledForKey(SCIWPrefHoldUpdates)) {
        %orig;
        return;
    }
    SCIWRecordAnswer(@"update check held");
}

%end

%end


void SCIWInstallUpdateGuard(void) {
    Class manager = NSClassFromString(@"SUBManager");
    SCIWRecordClass(@"SUBManager", manager != nil);

    if (!manager) {
        sciwGuardState = @"SUBManager is not in this process — nothing installed";
        SCIWPublishGuardState();
        return;
    }

    //
    // **Each selector decides for itself, and a missing one is not a failure of the other.**
    //
    // The first version demanded both and installed neither when one was absent -- so a device
    // carrying a perfectly hookable `-scanForUpdates` got no hold at all, reported as "signatures
    // do not match". That is the same shape as a capability check narrower than the capability it
    // guards: it fails silently in the direction of doing less.
    //
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    if (SCIWEncodingMatches(manager, @"scanForUpdates", kSCIWScanEncoding)) {
        %init(UpdateHoldScan);
        [installed addObject:@"-scanForUpdates"];
    } else {
        [skipped addObject:SCIWDescribeSelector(manager, @"scanForUpdates", kSCIWScanEncoding)];
    }

    if (SCIWEncodingMatches(manager, @"checkForSoftwareUpdate:", kSCIWCheckEncoding)) {
        %init(UpdateHoldCheck);
        [installed addObject:@"-checkForSoftwareUpdate:"];
    } else {
        [skipped addObject:SCIWDescribeSelector(manager, @"checkForSoftwareUpdate:",
                                                kSCIWCheckEncoding)];
    }

    sciwGuardState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [NSString stringWithFormat:@"installed on SUBManager: %@",
                              [installed componentsJoinedByString:@", "]]
                        : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@",
                            [skipped componentsJoinedByString:@"; "]]
                      : @""];
    SCIWPublishGuardState();
}

NSString *SCIWUpdateGuardReport(void) {
    return sciwGuardState ?: @"not reached — the Watch app has not been opened this launch";
}
