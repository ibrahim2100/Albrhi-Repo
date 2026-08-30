#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SCITWSpacesBar.h"
#import "Features/Switches/SCITWFeatures.h"
#import "SCILog.h"

///
/// Withheld, not emptied. The setup call is simply not made when the feature is on, so
/// nothing downstream is ever handed a half-built bar — which is the same distinction the
/// Watch tweak paid for: refusing a delivery and feeding nil into a state machine are not
/// the same thing, and the second one crashes.
///

static BOOL sciModernPresent = NO, sciLegacyPresent = NO;
static NSUInteger sciModernHeld = 0, sciLegacyHeld = 0;
static NSUInteger sciModernAsked = 0, sciLegacyAsked = 0;

static BOOL sciSpacesOn(void) { return [SCITWFeatures isOnIdentifier:@"spaces"]; }


%group SpacesBarModern

%hook THFHomeTimelineItemsViewController

- (void)_t1_initializeFleets {
    sciModernAsked++;
    if (!sciSpacesOn()) {
        %orig;
        return;
    }
    sciModernHeld++;
}

%end

%end


%group SpacesBarLegacy

%hook T1HomeTimelineItemsViewController

- (void)_t1_initializeFleets {
    sciLegacyAsked++;
    if (!sciSpacesOn()) {
        %orig;
        return;
    }
    sciLegacyHeld++;
}

%end

%end


/// Whether a class both exists and declares the method.
///
/// The existence half is not enough on its own. **A `%hook` on a method a class does not
/// declare does not politely do nothing — Logos adds it**, and this tweak would then be
/// inventing an API X never calls, on a class whose superclass may well implement it.
static BOOL SCITWDeclaresFleets(NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) return NO;
    return class_getInstanceMethod(cls, NSSelectorFromString(@"_t1_initializeFleets")) != NULL;
}

NSString *SCITWSpacesBarReport(void) {
    if (!sciModernPresent && !sciLegacyPresent) {
        return @"spaces bar: neither home timeline class declares _t1_initializeFleets";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (sciModernPresent) {
        [parts addObject:[NSString stringWithFormat:@"THF asked %lu, held %lu",
                          (unsigned long)sciModernAsked, (unsigned long)sciModernHeld]];
    }
    if (sciLegacyPresent) {
        [parts addObject:[NSString stringWithFormat:@"T1 asked %lu, held %lu",
                          (unsigned long)sciLegacyAsked, (unsigned long)sciLegacyHeld]];
    }
    if (!sciSpacesOn()) [parts addObject:@"feature off"];

    return [@"spaces bar: " stringByAppendingString:
            [parts componentsJoinedByString:@" · "]];
}

void SCITWInstallSpacesBar(void) {
    sciModernPresent = SCITWDeclaresFleets(@"THFHomeTimelineItemsViewController");
    sciLegacyPresent = SCITWDeclaresFleets(@"T1HomeTimelineItemsViewController");

    if (sciModernPresent) {
        %init(SpacesBarModern);
    }
    if (sciLegacyPresent) {
        %init(SpacesBarLegacy);
    }

    SCILogV(@"spaces bar: modern %d, legacy %d", sciModernPresent, sciLegacyPresent);
}
