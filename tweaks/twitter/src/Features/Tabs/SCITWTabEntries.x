#import <Foundation/Foundation.h>
#import "SCITWTabEntries.h"
#import "Features/Switches/SCITWFeatures.h"
#import "SCILog.h"

///
/// Every tab entry answers the same two questions, so the enforcement is the same three
/// lines three times over rather than anything clever. What differs is only which feature
/// owns the answer and which way it points: "More tabs" wants Communities and Profile in
/// the bar, "Hide Spaces" wants Voice out of it.
///
/// Both getters are forced together on purpose. `-isTabViewSideBarOnly` is the iPad half of
/// the same decision, and a tab included in the bar while still marked sidebar-only is a
/// tab that appears on one device and not the other -- the kind of half-applied change that
/// reads on a phone as "it worked" and is a bug report from anyone on an iPad.
///

static BOOL sciTabsOn(void) { return [SCITWFeatures isOnIdentifier:@"tabs"]; }
static BOOL sciSpacesOn(void) { return [SCITWFeatures isOnIdentifier:@"spaces"]; }

// Present: the class is in this build at all. Asked: X actually consulted the getter.
// Kept apart because "no tab appeared" has those two entirely different causes, and one
// counter cannot say which -- the same tally-versus-snapshot lesson TikTok's own status
// row cost three releases.
static BOOL sciCommunitiesPresent = NO, sciProfilePresent = NO, sciVoicePresent = NO;
static NSUInteger sciCommunitiesAsked = 0, sciProfileAsked = 0, sciVoiceAsked = 0;
static NSUInteger sciCommunitiesForced = 0, sciProfileForced = 0, sciVoiceForced = 0;


%group TabCommunities

%hook _TtC14T1TwitterSwift34T1CommunitiesAppNavigationTabEntry

- (BOOL)isExcludedFromTabBar {
    sciCommunitiesAsked++;
    if (!sciTabsOn()) return %orig;
    sciCommunitiesForced++;
    return NO;
}

- (BOOL)isTabViewSideBarOnly {
    if (!sciTabsOn()) return %orig;
    return NO;
}

%end

%end


%group TabProfile

%hook _TtC14T1TwitterSwift28ProfileAppNavigationTabEntry

- (BOOL)isExcludedFromTabBar {
    sciProfileAsked++;
    if (!sciTabsOn()) return %orig;
    sciProfileForced++;
    return NO;
}

- (BOOL)isTabViewSideBarOnly {
    if (!sciTabsOn()) return %orig;
    return NO;
}

%end

%end


%group TabVoice

%hook _TtC14T1TwitterSwift26VoiceAppNavigationTabEntry

- (BOOL)isExcludedFromTabBar {
    sciVoiceAsked++;
    if (!sciSpacesOn()) return %orig;
    sciVoiceForced++;
    return YES;
}

%end

%end


static NSString *SCITWTabEntryLine(NSString *name, BOOL present, NSUInteger asked,
                                   NSUInteger forced, BOOL featureOn) {
    if (!present) return [NSString stringWithFormat:@"  %@ — not in this build", name];
    if (!featureOn) return [NSString stringWithFormat:@"  %@ — hooked, its feature is off", name];
    if (asked == 0) {
        // The one outcome worth naming rather than counting. X building the bar without ever
        // asking this entry means the entry is not the gate -- and that is a different
        // investigation from a gate that was asked and overruled.
        return [NSString stringWithFormat:@"  %@ — hooked, never asked (X did not consult it)",
                name];
    }
    return [NSString stringWithFormat:@"  %@ — asked %lu, answered ours %lu",
            name, (unsigned long)asked, (unsigned long)forced];
}

NSString *SCITWTabEntriesReport(void) {
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"tab entries:"];
    [text appendString:@"\n"];
    [text appendString:SCITWTabEntryLine(@"Communities", sciCommunitiesPresent,
                                         sciCommunitiesAsked, sciCommunitiesForced, sciTabsOn())];
    [text appendString:@"\n"];
    [text appendString:SCITWTabEntryLine(@"Profile", sciProfilePresent,
                                         sciProfileAsked, sciProfileForced, sciTabsOn())];
    [text appendString:@"\n"];
    [text appendString:SCITWTabEntryLine(@"Spaces", sciVoicePresent,
                                         sciVoiceAsked, sciVoiceForced, sciSpacesOn())];
    return text;
}

void SCITWInstallTabEntries(void) {
    sciCommunitiesPresent =
        (NSClassFromString(@"_TtC14T1TwitterSwift34T1CommunitiesAppNavigationTabEntry") != nil);
    sciProfilePresent =
        (NSClassFromString(@"_TtC14T1TwitterSwift28ProfileAppNavigationTabEntry") != nil);
    sciVoicePresent =
        (NSClassFromString(@"_TtC14T1TwitterSwift26VoiceAppNavigationTabEntry") != nil);

    if (sciCommunitiesPresent) {
        %init(TabCommunities);
    }
    if (sciProfilePresent) {
        %init(TabProfile);
    }
    if (sciVoicePresent) {
        %init(TabVoice);
    }

    SCILogV(@"tab entries: communities %d, profile %d, voice %d",
            sciCommunitiesPresent, sciProfilePresent, sciVoicePresent);
}
