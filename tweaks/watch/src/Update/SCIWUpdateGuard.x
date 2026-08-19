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

static BOOL SCIWEncodingMatches(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    if (!types) return NO;

    return [expected isEqualToString:[NSString stringWithUTF8String:types]];
}

%group UpdateHold

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
        return;
    }

    BOOL scan = SCIWEncodingMatches(manager, @"scanForUpdates", kSCIWScanEncoding);
    BOOL check = SCIWEncodingMatches(manager, @"checkForSoftwareUpdate:", kSCIWCheckEncoding);

    if (!scan || !check) {
        // Named precisely, because this is the report that turns into the next release: the
        // encoding is what a hook has to be rewritten against, and "it did not work" would not
        // carry it.
        Method scanMethod = class_getInstanceMethod(manager, NSSelectorFromString(@"scanForUpdates"));
        Method checkMethod = class_getInstanceMethod(manager,
            NSSelectorFromString(@"checkForSoftwareUpdate:"));

        sciwGuardState = [NSString stringWithFormat:
            @"signatures do not match — nothing installed. -scanForUpdates is %s (expected %@), "
            @"-checkForSoftwareUpdate: is %s (expected %@)",
            scanMethod ? method_getTypeEncoding(scanMethod) : "missing", kSCIWScanEncoding,
            checkMethod ? method_getTypeEncoding(checkMethod) : "missing", kSCIWCheckEncoding];
        return;
    }

    %init(UpdateHold);
    sciwGuardState = @"installed on SUBManager (scan + check)";
}

NSString *SCIWUpdateGuardReport(void) {
    return sciwGuardState ?: @"not reached — the Watch app has not been opened this launch";
}
