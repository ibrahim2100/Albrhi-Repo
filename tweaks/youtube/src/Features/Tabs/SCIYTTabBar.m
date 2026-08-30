#import "SCIYTTabBar.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

const NSUInteger SCIYTTabBarMaximum = 6;

/// Ours. Kept in step with SCIYTTabEntry.x by hand, because a shared constant between a
/// `.x` and a `.m` would mean a header whose only content is one string -- and if these
/// ever drift, the Download Centre tab simply appears under its raw identifier in the
/// list, which is visible rather than silent.
static NSString *const kSCIDownloadsPivot = @"albrhi.downloads.pivot";

/// Names for the identifiers YouTube is known to use, so a list of `FE…` tokens reads as a
/// list of tabs. **This never decides that a tab exists** -- only what to call one the bar
/// has already handed us.
static NSDictionary<NSString *, NSString *> *SCIKnownNames(void) {
    static NSDictionary *names = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @{
            @"FEwhat_to_watch": @"tab_home",
            @"FEshorts": @"tab_shorts",
            @"FEsubscriptions": @"tab_subscriptions",
            @"FElibrary": @"tab_you",
            @"FEexplore": @"tab_explore",
            @"FEhistory": @"tab_history",
            @"FEuploads": @"tab_uploads",
        };
    });
    return names;
}

static NSMutableArray<NSString *> *sciSeen = nil;
static NSUInteger sciLastSeenCount = 0, sciLastKeptCount = 0, sciLastDroppedCount = 0;
static BOOL sciEverArranged = NO;

NSArray<NSString *> *SCIYTTabBarSeenIdentifiers(void) {
    if (sciSeen.count) return [sciSeen copy];

    // Remembered across launches, because the settings screen is usually opened from a
    // fresh process and a list that is empty until the bar happens to rebuild reads as a
    // broken screen.
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:@"tab_bar_seen"];
    return [stored isKindOfClass:[NSArray class]] ? stored : @[];
}

void SCIYTTabBarNoteIdentifier(NSString *identifier) {
    if (!identifier.length) return;
    if (!sciSeen) sciSeen = [NSMutableArray array];
    if ([sciSeen containsObject:identifier]) return;

    [sciSeen addObject:identifier];
    [[NSUserDefaults standardUserDefaults] setObject:[sciSeen copy] forKey:@"tab_bar_seen"];
}

NSString *SCIYTTabBarDisplayName(NSString *identifier) {
    if ([identifier isEqualToString:kSCIDownloadsPivot]) return SCILocalized(@"dl_centre_title");

    NSString *key = SCIKnownNames()[identifier];
    if (key) return SCILocalized(key);

    // Shown as itself rather than hidden or renamed to something invented. An unnamed tab
    // is still a tab somebody may want to move, and a wrong name is worse than a raw one.
    return identifier;
}

static NSArray<NSString *> *SCIStoredArray(NSString *key) {
    NSArray *value = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
    if (![value isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray *strings = [NSMutableArray array];
    for (id entry in value) {
        if ([entry isKindOfClass:[NSString class]]) [strings addObject:entry];
    }
    return strings;
}

NSArray<NSString *> *SCIYTTabBarActiveOrder(void) { return SCIStoredArray(SCIPrefTabOrder); }
NSArray<NSString *> *SCIYTTabBarHiddenIdentifiers(void) { return SCIStoredArray(SCIPrefTabHidden); }

void SCIYTTabBarSetActiveOrder(NSArray<NSString *> *active, NSArray<NSString *> *hidden) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:active ?: @[] forKey:SCIPrefTabOrder];
    [defaults setObject:hidden ?: @[] forKey:SCIPrefTabHidden];
}

/// The identifier of one entry in the bar's items array, or nil.
///
/// KVC rather than a message send, for the reason the Download Centre tab already records:
/// these are GPBMessage subclasses whose fields resolve dynamically, so
/// `-respondsToSelector:` answers NO for a field `-valueForKey:` reads perfectly well.
static NSString *SCIIdentifierOf(id entry) {
    @try {
        id inner = [entry valueForKey:@"pivotBarItemRenderer"];
        if (!inner) return nil;
        id identifier = [inner valueForKey:@"pivotIdentifier"];
        return [identifier isKindOfClass:[NSString class]] ? identifier : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

void SCIYTTabBarArrange(NSMutableArray *items) {
    if (!items.count) return;

    NSArray<NSString *> *order = SCIYTTabBarActiveOrder();
    NSArray<NSString *> *hidden = SCIYTTabBarHiddenIdentifiers();

    // Every entry is noted whether or not anything is being changed. The settings screen
    // can only offer what has been seen, and someone opens that screen precisely because
    // they have not arranged anything yet.
    NSMutableArray *named = [NSMutableArray arrayWithCapacity:items.count];
    for (id entry in items) {
        NSString *identifier = SCIIdentifierOf(entry);
        if (identifier) SCIYTTabBarNoteIdentifier(identifier);
        [named addObject:identifier ?: [NSNull null]];
    }

    sciEverArranged = YES;
    sciLastSeenCount = items.count;

    if (!order.count && !hidden.count) {
        sciLastKeptCount = items.count;
        sciLastDroppedCount = 0;
        return;
    }

    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:items.count];
    NSMutableArray *tail = [NSMutableArray array];

    // Anything the stored order does not mention keeps its place at the end. A tab YouTube
    // adds after this list was written should appear, not disappear -- an arrangement is a
    // preference about what was seen, never a whitelist.
    for (NSUInteger i = 0; i < items.count; i++) {
        id identifier = named[i];
        if (identifier == (id)[NSNull null]) { [tail addObject:items[i]]; continue; }
        if ([hidden containsObject:identifier]) continue;
        if (![order containsObject:identifier]) [tail addObject:items[i]];
    }

    for (NSString *identifier in order) {
        for (NSUInteger i = 0; i < items.count; i++) {
            if ([named[i] isEqual:identifier]) { [kept addObject:items[i]]; break; }
        }
    }
    [kept addObjectsFromArray:tail];

    if (kept.count > SCIYTTabBarMaximum) {
        [kept removeObjectsInRange:NSMakeRange(SCIYTTabBarMaximum,
                                               kept.count - SCIYTTabBarMaximum)];
    }

    // Never an empty bar. A stored list matching nothing -- a rename by YouTube, a restored
    // backup from another account -- would otherwise leave the app with no way to navigate.
    if (kept.count == 0) {
        sciLastKeptCount = items.count;
        sciLastDroppedCount = 0;
        SCILogV(@"tab arrangement matched nothing; the bar is left alone");
        return;
    }

    sciLastKeptCount = kept.count;
    sciLastDroppedCount = items.count > kept.count ? items.count - kept.count : 0;

    [items removeAllObjects];
    [items addObjectsFromArray:kept];
}

NSString *SCIYTTabBarReport(void) {
    if (!sciEverArranged) return @"tab bar: not built yet this launch";

    NSArray<NSString *> *seen = SCIYTTabBarSeenIdentifiers();
    return [NSString stringWithFormat:@"tab bar: %lu handed, %lu kept, %lu dropped · seen: %@",
            (unsigned long)sciLastSeenCount, (unsigned long)sciLastKeptCount,
            (unsigned long)sciLastDroppedCount,
            seen.count ? [seen componentsJoinedByString:@", "] : @"none"];
}
