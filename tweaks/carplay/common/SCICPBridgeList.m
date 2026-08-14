#import "SCICPBridgeList.h"
#import "shared/src/SCIPanelGate.h"
#import "shared/src/SCICPPrefsKeys.h"

/// Read once per process and kept, the same reasoning as SCIPanelAllowsThisApp: this
/// is asked on a hot path (every scene-configuration lookup in a bridged app), and
/// the list cannot change during this process's own life -- a change written from
/// Settings reaches a process only the next time it launches, which is already how
/// every switch in this tweak behaves and is stated as such everywhere it matters.
static NSSet<NSString *> *SCICPBridgedBundleIdentifiers(void) {
    static NSSet<NSString *> *bundles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *raw = SCIPanelReadString(SCICPBridgedAppsKey, @"");
        NSMutableSet<NSString *> *parsed = [NSMutableSet set];
        for (NSString *entry in [raw componentsSeparatedByString:@","]) {
            NSString *trimmed = [entry stringByTrimmingCharactersInSet:
                                  NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmed.length) [parsed addObject:trimmed];
        }
        bundles = [parsed copy];
    });
    return bundles;
}

BOOL SCICPBundleIsBridged(NSString *bundleID) {
    if (!bundleID.length) return NO;
    return [SCICPBridgedBundleIdentifiers() containsObject:bundleID];
}
