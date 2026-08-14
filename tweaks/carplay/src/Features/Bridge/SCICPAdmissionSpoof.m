#import "SCICPAdmissionSpoof.h"
#import "SCILog.h"
#import "SCICPBridgeList.h"
#import "../../Diagnostics/SCICPDiagnostics.h"
#import <objc/message.h>
#import <objc/runtime.h>

/// Guarded the same way every other hook in this project is: never installed unless
/// the class and the exact selector are both already there, and never adds a method
/// that was not already declared -- a selector this iOS build renamed is a spoof that
/// silently does nothing, not a crash.
static BOOL SCICPSwizzleInstanceMethod(Class cls, SEL sel, IMP replacement, IMP *outOriginal) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return NO;

    if (outOriginal) *outOriginal = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return YES;
}

static NSString *SCICPProxyBundleIdentifier(id proxy) {
    SEL sel = @selector(bundleIdentifier);
    if (![proxy respondsToSelector:sel]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

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

        NSString *bundleID = SCICPProxyBundleIdentifier(self);
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

        NSString *bundleID = SCICPProxyBundleIdentifier(self);
        if (!bundleID || !SCICPBundleIsBridged(bundleID)) return value;

        SCICPLogAdmissionOnce(bundleID, key);
        return @YES;
    } @catch (__unused NSException *exception) {
        return value;
    }
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

    SCILogV(@"admission: spoof installed (3-arg=%d, 2-arg=%d)", three, two);
    [SCICPDiagnostics record:
        [NSString stringWithFormat:@"admission spoof installed (3-arg=%d, 2-arg=%d) — "
            "known to matter on iOS 16/17 only", three, two]];

    if (!three && !two) {
        SCILogV(@"admission: WARNING neither entitlement getter exists on this build");
    }
}
