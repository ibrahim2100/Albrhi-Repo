#import "SCICPAdmissionSpoof.h"
#import "SCICPSceneManifestSpoof.h"
#import "SCICPLSProxy.h"
#import "SCILog.h"
#import "SCICPBridgeList.h"
#import "../../Diagnostics/SCICPDiagnostics.h"
#import <objc/message.h>
#import <objc/runtime.h>

/// The two flags CarPlay's own admission check reads as "this app may reach the
/// dashboard" on iOS 16/17. Neither is a real Apple-issued CarPlay entitlement --
/// those (com.apple.developer.carplay-*) stay untouched here, same as every hook in
/// this file only ever answers a question CarPlay already asks rather than inventing
/// a stronger claim than "may appear on the dashboard".
static BOOL SCICPIsCapabilityKey(NSString *key) {
    return [key isEqualToString:@"CARCapableApp"] || [key isEqualToString:@"SBStarkCapable"];
}

static void SCICPLogAdmissionOnce(NSString *bundleID, NSString *key) {
    static NSMutableSet<NSString *> *seen;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet set]; });

    NSString *identity = [NSString stringWithFormat:@"%@|%@", bundleID, key];
    @synchronized (seen) {
        if ([seen containsObject:identity]) return;
        [seen addObject:identity];
    }
    SCILogV(@"admission: answered %@ for %@", key, bundleID);
    [SCICPDiagnostics record:[NSString stringWithFormat:@"admitted %@ via %@", bundleID, key]];
}

#pragma mark - entitlementValueForKey:ofClass:valuesOfClass:

static id (*sciOrigEntitlementValue3)(id, SEL, NSString *, Class, Class);

static id sciEntitlementValue3(id self, SEL _cmd, NSString *key, Class expected, Class valuesExpected) {
    id value = sciOrigEntitlementValue3(self, _cmd, key, expected, valuesExpected);
    if (value) return value;   // a real answer always wins over a spoofed one

    @try {
        if (!SCICPIsCapabilityKey(key)) return value;
        if (expected && expected != NSNumber.class) return value;

        NSString *bundleID = SCICPLSProxyBundleIdentifier(self);
        if (!bundleID || !SCICPBundleIsBridged(bundleID)) return value;

        SCICPLogAdmissionOnce(bundleID, key);
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

#pragma mark - entitlementValueForKey:ofClass:

static id (*sciOrigEntitlementValue2)(id, SEL, NSString *, Class);

static id sciEntitlementValue2(id self, SEL _cmd, NSString *key, Class expected) {
    id value = sciOrigEntitlementValue2(self, _cmd, key, expected);
    if (value) return value;

    @try {
        if (!SCICPIsCapabilityKey(key)) return value;
        if (expected && expected != NSNumber.class) return value;

        NSString *bundleID = SCICPLSProxyBundleIdentifier(self);
        if (!bundleID || !SCICPBundleIsBridged(bundleID)) return value;

        SCICPLogAdmissionOnce(bundleID, key);
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

#pragma mark - entitlementValuesForKeys: (bulk, and SpringBoard's own route)

// SpringBoard does not read entitlements one key at a time the way CarPlay's
// DashBoard does. Its own app-library code calls this bulk getter, and on a real
// device it does not hand back an NSDictionary at all -- it returns a private
// LSBundleInfoCachedValues, and callers then pull values out through -boolForKey:
// and its siblings below. Handing back a *replacement* dictionary where the caller
// expects that private object is exactly the kind of type mismatch that aborts a
// system process on an unrecognized selector; the safe move is to leave the real
// object untouched and remember which ones belong to a bridged bundle, then answer
// capability questions for a tagged object only, in the accessor hooks that follow.
static NSHashTable *SCICPTaggedCachedValues(void) {
    static NSHashTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ table = [NSHashTable weakObjectsHashTable]; });
    return table;
}

static NSLock *SCICPTagLock(void) {
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSLock new]; });
    return lock;
}

static void SCICPTagCachedValues(id object) {
    if (!object) return;
    NSLock *lock = SCICPTagLock();
    [lock lock];
    [SCICPTaggedCachedValues() addObject:object];
    [lock unlock];
}

static BOOL SCICPIsTaggedCachedValues(id object) {
    if (!object) return NO;
    NSLock *lock = SCICPTagLock();
    [lock lock];
    BOOL tagged = [SCICPTaggedCachedValues() containsObject:object];
    [lock unlock];
    return tagged;
}

static id (*sciOrigEntitlementValuesForKeys)(id, SEL, NSArray *);

static id sciEntitlementValuesForKeys(id self, SEL _cmd, NSArray *keys) {
    id result = sciOrigEntitlementValuesForKeys(self, _cmd, keys);

    @try {
        NSString *bundleID = SCICPLSProxyBundleIdentifier(self);
        if (!bundleID || !SCICPBundleIsBridged(bundleID)) return result;

        if (![result isKindOfClass:NSDictionary.class]) {
            // Not a dictionary: the private cached-values object. Tag it and hand
            // it back exactly as received.
            SCICPTagCachedValues(result);
            SCILogV(@"admission: tagged app-library entry for %@ (%@)", bundleID,
                    result ? NSStringFromClass([result class]) : @"nil");
            return result;
        }

        if (![keys isKindOfClass:NSArray.class]) return result;

        NSMutableDictionary *patched = nil;
        for (NSString *key in keys) {
            if (!SCICPIsCapabilityKey(key)) continue;
            if (((NSDictionary *)result)[key]) continue;
            if (!patched) patched = [result mutableCopy];
            patched[key] = @YES;
        }
        if (!patched) return result;

        SCICPLogAdmissionOnce(bundleID, @"entitlementValuesForKeys:");
        return patched;
    } @catch (__unused NSException *exception) {
        return result;
    }
}

#pragma mark - LSBundleInfoCachedValues accessors

// The other half of the bulk hook above: these only ever answer a capability key,
// and only for an object the bulk hook already tagged as belonging to a bridged
// bundle. Every other question passes straight to the real implementation
// unchanged, which is what keeps this from ever answering something CarPlay did
// not itself ask about.

static BOOL SCICPShouldAnswerCachedValue(id self, NSString *key, id existing) {
    return !existing && SCICPIsCapabilityKey(key) && SCICPIsTaggedCachedValues(self);
}

static BOOL (*sciOrigCachedBoolForKey)(id, SEL, NSString *);

static BOOL sciCachedBoolForKey(id self, SEL _cmd, NSString *key) {
    BOOL value = sciOrigCachedBoolForKey(self, _cmd, key);
    @try {
        if (value || !SCICPIsCapabilityKey(key) || !SCICPIsTaggedCachedValues(self)) return value;
        SCILogV(@"admission: answered boolForKey:%@ for a tagged app-library entry", key);
        return YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

static id (*sciOrigCachedObjectForKey)(id, SEL, NSString *);

static id sciCachedObjectForKey(id self, SEL _cmd, NSString *key) {
    id value = sciOrigCachedObjectForKey(self, _cmd, key);
    @try {
        if (!SCICPShouldAnswerCachedValue(self, key, value)) return value;
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

static id (*sciOrigCachedNumberForKey)(id, SEL, NSString *);

static id sciCachedNumberForKey(id self, SEL _cmd, NSString *key) {
    id value = sciOrigCachedNumberForKey(self, _cmd, key);
    @try {
        if (!SCICPShouldAnswerCachedValue(self, key, value)) return value;
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

static id (*sciOrigCachedObjectForKeyOfClass)(id, SEL, NSString *, Class);

static id sciCachedObjectForKeyOfClass(id self, SEL _cmd, NSString *key, Class expected) {
    id value = sciOrigCachedObjectForKeyOfClass(self, _cmd, key, expected);
    @try {
        if (!SCICPShouldAnswerCachedValue(self, key, value)) return value;
        if (expected && expected != NSNumber.class) return value;
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

static id (*sciOrigCachedObjectForKeyOfClassValues)(id, SEL, NSString *, Class, Class);

static id sciCachedObjectForKeyOfClassValues(id self, SEL _cmd, NSString *key,
                                              Class expected, Class valuesExpected) {
    id value = sciOrigCachedObjectForKeyOfClassValues(self, _cmd, key, expected, valuesExpected);
    @try {
        if (!SCICPShouldAnswerCachedValue(self, key, value)) return value;
        if (expected && expected != NSNumber.class) return value;
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
}

static void SCICPInstallCachedValuesHooks(void) {
    Class cls = NSClassFromString(@"LSBundleInfoCachedValues");
    if (!cls) {
        SCILogV(@"admission: LSBundleInfoCachedValues absent — SpringBoard's app "
                "library cannot be answered on this release");
        return;
    }

    BOOL b = SCICPSwizzleInstanceMethod(cls, @selector(boolForKey:),
        (IMP)sciCachedBoolForKey, (IMP *)&sciOrigCachedBoolForKey);
    BOOL o = SCICPSwizzleInstanceMethod(cls, @selector(objectForKey:),
        (IMP)sciCachedObjectForKey, (IMP *)&sciOrigCachedObjectForKey);
    BOOL n = SCICPSwizzleInstanceMethod(cls, @selector(numberForKey:),
        (IMP)sciCachedNumberForKey, (IMP *)&sciOrigCachedNumberForKey);
    BOOL oc = SCICPSwizzleInstanceMethod(cls, sel_getUid("objectForKey:ofClass:"),
        (IMP)sciCachedObjectForKeyOfClass, (IMP *)&sciOrigCachedObjectForKeyOfClass);
    BOOL ocv = SCICPSwizzleInstanceMethod(cls, sel_getUid("objectForKey:ofClass:valuesOfClass:"),
        (IMP)sciCachedObjectForKeyOfClassValues, (IMP *)&sciOrigCachedObjectForKeyOfClassValues);

    SCILogV(@"admission: app-library accessors hooked (bool=%d object=%d number=%d "
            "ofClass=%d ofClassValues=%d)", b, o, n, oc, ocv);
}

#pragma mark - Install

void SCICPInstallAdmissionSpoof(void) {
    Class proxy = NSClassFromString(@"LSBundleProxy");
    if (!proxy) {
        SCILogV(@"admission: LSBundleProxy absent — nothing to hook");
        return;
    }

    BOOL three = SCICPSwizzleInstanceMethod(
        proxy, sel_getUid("entitlementValueForKey:ofClass:valuesOfClass:"),
        (IMP)sciEntitlementValue3, (IMP *)&sciOrigEntitlementValue3);

    BOOL two = SCICPSwizzleInstanceMethod(
        proxy, sel_getUid("entitlementValueForKey:ofClass:"),
        (IMP)sciEntitlementValue2, (IMP *)&sciOrigEntitlementValue2);

    BOOL bulk = SCICPSwizzleInstanceMethod(
        proxy, @selector(entitlementValuesForKeys:),
        (IMP)sciEntitlementValuesForKeys, (IMP *)&sciOrigEntitlementValuesForKeys);

    SCICPInstallCachedValuesHooks();

    // The other half of the gate: what LSBundleProxy says the app's own Info.plist
    // declares, read before the app is ever launched. Both have to be covered or an
    // app is admitted to the library and CarPlay still never asks it for a scene.
    SCICPInstallSceneManifestSpoof();

    SCILogV(@"admission: spoof installed (3-arg=%d, 2-arg=%d, bulk=%d)", three, two, bulk);
    [SCICPDiagnostics record:
        [NSString stringWithFormat:@"admission spoof installed (3-arg=%d, 2-arg=%d, bulk=%d) — "
            "known to matter on iOS 16/17 only", three, two, bulk]];

    if (!three && !two) {
        SCILogV(@"admission: WARNING neither entitlement getter exists on this build");
    }
}
