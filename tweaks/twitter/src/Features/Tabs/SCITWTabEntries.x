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
static BOOL sciTabBarPresent = NO;
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


///
/// The tab entry was not enough for Spaces, and the reason is the same trap the feature
/// switch fell into. `-isExcludedFromTabBar` is consulted while X composes the set of tabs
/// it *could* show; an account that already has a saved bar keeps the bar it saved, so
/// excluding the entry changes what a new account would get and nothing else -- exactly
/// what `ios_tab_bar_default_show_communities` did, one layer down.
///
/// So the final array is filtered as well. `-setTabViews:` is the last point at which the
/// bar is told what to draw, after any saved configuration, and each `T1TabView` carries
/// `scribePage` -- the tab's own stable name. The Spaces tab is `audiospace`, which is a
/// token X itself carries (four times in `T1Twitter`), not a name invented here.
///
/// Communities went the other way and worked at the entry, so that half is left where it
/// is: this filter only removes.
///

@interface T1TabView : UIView
@property (nonatomic, copy, readonly) NSString *scribePage;
@end

static NSString *const kSCITWSpacesTabPage = @"audiospace";

static NSUInteger sciTabViewsSeen = 0, sciTabViewsRemoved = 0;
// Every name the bar has actually carried, so a build that calls the Spaces tab something
// else is diagnosable from one report instead of another round of guessing at tokens.
static NSMutableOrderedSet<NSString *> *sciTabPagesSeen = nil;

%group TabBarFilter

%hook T1TabBarViewController

- (void)setTabViews:(NSArray *)tabViews {
    if (!sciSpacesOn() || tabViews.count == 0) {
        %orig;
        return;
    }

    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:tabViews.count];
    for (id tab in tabViews) {
        sciTabViewsSeen++;

        NSString *page = nil;
        if ([tab respondsToSelector:@selector(scribePage)]) page = [(T1TabView *)tab scribePage];
        if (page.length) [sciTabPagesSeen addObject:page];

        if (page.length && [page caseInsensitiveCompare:kSCITWSpacesTabPage] == NSOrderedSame) {
            sciTabViewsRemoved++;
            continue;
        }
        [kept addObject:tab];
    }

    // Never hand back an empty bar. A filter that can remove every tab is a filter that can
    // leave the app with no navigation at all, and a wrong token is exactly how that
    // happens -- the same reason the download button was not hidden when a lookup failed.
    if (kept.count == 0) {
        %orig;
        return;
    }

    %orig(kept);
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

    [text appendString:@"\n"];
    if (!sciTabBarPresent) {
        [text appendString:@"  tab bar — T1TabBarViewController not in this build"];
    } else if (sciTabViewsSeen == 0) {
        [text appendString:@"  tab bar — hooked, never set (X did not hand it any tabs)"];
    } else {
        [text appendFormat:@"  tab bar — %lu tab(s) seen, %lu removed, pages: %@",
                (unsigned long)sciTabViewsSeen, (unsigned long)sciTabViewsRemoved,
                [[sciTabPagesSeen array] componentsJoinedByString:@", "]];
    }
    return text;
}

void SCITWInstallTabEntries(void) {
    sciTabPagesSeen = [NSMutableOrderedSet orderedSet];

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

    sciTabBarPresent = (NSClassFromString(@"T1TabBarViewController") != nil);
    if (sciTabBarPresent) {
        %init(TabBarFilter);
    }

    SCILogV(@"tab entries: communities %d, profile %d, voice %d, bar %d",
            sciCommunitiesPresent, sciProfilePresent, sciVoicePresent, sciTabBarPresent);
}
