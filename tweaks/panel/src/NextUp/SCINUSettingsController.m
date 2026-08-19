#import "SCINUSettingsController.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import "../Localization/SCILocalize.h"

///
/// Upstream's preference plumbing, used exactly as upstream's own pane used it.
///
/// Two channels, and both are needed. CFPreferences is the persisted value, read
/// reliably when an injected process starts. The notify_state token is the *live* one:
/// a cross-process CFPreferences read is cached and would only pick a toggle up after a
/// respring, so the token is what makes a switch take effect while Music or SpringBoard
/// is already running. Writing one without the other gives a switch that either forgets
/// itself on reboot or does nothing until you respring — upstream documents this and the
/// port keeps it rather than rediscovering it.
///
/// The domain and the bit layout are upstream's, not renamed. The reader
/// (`NUPrefs.m`, shipped unchanged in tweaks/nextup) compiles those names in, so a
/// rebrand here would be a silent disconnect: every switch would write somewhere the
/// tweak never looks. `control` declares Conflicts on com.yves.nextup3 so the two
/// packages can never both be installed and race for the same names.
static NSString *const kNUDomain = @"com.yves.nextup3";
static const char *const kNUStateNotifyName = "com.yves.nextup3.state";

static const uint64_t kNUStateValidBit      = (1ULL << 63);
static const int      kNUStateKnownShift    = 32;

/// Key → bit, mirroring NUStateBitForKey() in the tweak's own NUPrefs.h. Kept as a table
/// so the publish step below cannot drift from the list of switches this page draws.
typedef struct { __unsafe_unretained NSString *key; uint64_t bit; } SCINUToggle;

static const SCINUToggle kSCINUToggles[] = {
    { @"Enabled",             1ULL << 0 },
    { @"enabledMusic",        1ULL << 1 },
    { @"enabledPodcasts",     1ULL << 2 },
    { @"showLockScreen",      1ULL << 3 },
    { @"showDynamicIsland",   1ULL << 4 },
    { @"showControlCenter",   1ULL << 5 },
    { @"enabledYouTubeMusic", 1ULL << 6 },
    { @"enabledSpotify",      1ULL << 7 },
    { @"enabledYouTube",      1ULL << 8 },
};

static const size_t kSCINUToggleCount = sizeof(kSCINUToggles) / sizeof(kSCINUToggles[0]);

@implementation SCINUSettingsController

// MARK: - Preferences

- (BOOL)sci_readBool:(NSString *)key fallback:(BOOL)fallback {
    // Settings is the writing process, so its own value can be stale in cache without
    // this — upstream's reader passes `fresh:YES` here for the same reason.
    CFPreferencesAppSynchronize((__bridge CFStringRef)kNUDomain);

    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)kNUDomain);
    if (!value) return fallback;

    BOOL result = (CFGetTypeID(value) == CFBooleanGetTypeID())
        ? CFBooleanGetValue((CFBooleanRef)value) : fallback;
    CFRelease(value);
    return result;
}

/// Rebuild the whole state word from the freshly written plist, stamp it valid, publish
/// and signal. A port of NUPrefsPublishState(); the word is rebuilt from scratch rather
/// than toggled bit-by-bit so a switch can never leave the token disagreeing with what
/// is actually stored.
- (void)sci_publishState {
    uint64_t mask = kNUStateValidBit;
    uint64_t known = 0;

    for (size_t i = 0; i < kSCINUToggleCount; i++) {
        // The same split the rows read with: the master is opt-in, everything else keeps
        // upstream's fail-open YES. Publishing a different default than the rows display
        // would put the token and the screen in disagreement the first time this runs,
        // before any value has actually been stored.
        BOOL optIn = [kSCINUToggles[i].key isEqualToString:@"Enabled"];
        if ([self sci_readBool:kSCINUToggles[i].key fallback:!optIn]) mask |= kSCINUToggles[i].bit;
        known |= kSCINUToggles[i].bit;
    }

    // The known-keys half says "the writer knew this key"; a value bit whose known bit is
    // clear makes the reader fall back to CFPreferences instead of trusting a zero.
    mask |= (known << kNUStateKnownShift);

    int token = -1;
    if (notify_register_check(kNUStateNotifyName, &token) == NOTIFY_STATUS_OK && token != -1) {
        notify_set_state(token, mask);
        notify_cancel(token);
    }
    notify_post(kNUStateNotifyName);
}

- (void)sci_writeBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)@(value),
                             (__bridge CFStringRef)kNUDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kNUDomain);

    // Persisted first, published second: the publish step re-reads the plist, so doing it
    // the other way round would broadcast the value this write was about to replace.
    [self sci_publishState];
}

// MARK: - Specifier plumbing

/// The switch's own key travels on the specifier, so adding a row costs one entry here
/// and nothing anywhere else — no second `if` ladder mapping a tag back to a key, which
/// is where this project has put a switch on the wrong preference before.
/// The master reads NO when nothing is stored; every other switch reads YES.
///
/// This has to agree exactly with `NUMasterEnabled()` in the tweak, which is opt-in for
/// the reason written there. A page that showed the master as on while the tweak read it
/// as off would be a screen stating the opposite of what is happening — worse than
/// either default on its own.
- (id)nuValueForSpecifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciNUKey"];
    BOOL optIn = [key isEqualToString:@"Enabled"];
    return @([self sci_readBool:key fallback:!optIn]);
}

- (void)setNuValue:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"sciNUKey"];
    if (!key.length) return;
    [self sci_writeBool:value.boolValue forKey:key];
}

- (PSSpecifier *)nuGroupTitled:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:(title ?: @"")
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:Nil
                                                           cell:PSGroupCell
                                                           edit:Nil];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

- (PSSpecifier *)nuSwitchTitled:(NSString *)title key:(NSString *)key {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                       target:self
                                                          set:@selector(setNuValue:specifier:)
                                                          get:@selector(nuValueForSpecifier:)
                                                       detail:Nil
                                                         cell:PSSwitchCell
                                                         edit:Nil];
    [row setProperty:key forKey:@"sciNUKey"];
    return row;
}

// MARK: - The page

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    [specifiers addObject:[self nuGroupTitled:nil footer:SCILocalized(@"nextup_master_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_master") key:@"Enabled"]];

    [specifiers addObject:[self nuGroupTitled:SCILocalized(@"nextup_where_section")
                                        footer:SCILocalized(@"nextup_where_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_lock_screen")
                                            key:@"showLockScreen"]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_dynamic_island")
                                            key:@"showDynamicIsland"]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_control_center")
                                            key:@"showControlCenter"]];

    [specifiers addObject:[self nuGroupTitled:SCILocalized(@"nextup_apps_section")
                                        footer:SCILocalized(@"nextup_apps_footer")]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_music")
                                            key:@"enabledMusic"]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_podcasts")
                                            key:@"enabledPodcasts"]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_youtube")
                                            key:@"enabledYouTube"]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_youtube_music")
                                            key:@"enabledYouTubeMusic"]];
    [specifiers addObject:[self nuSwitchTitled:SCILocalized(@"nextup_app_spotify")
                                            key:@"enabledSpotify"]];

    [specifiers addObject:[self nuGroupTitled:nil footer:SCILocalized(@"nextup_credit")]];

    // Assigned to the ivar, not just returned. PSListController's own machinery reads
    // _specifiers directly in places an override's return value never reaches, and a page
    // that only returns its list opens to a black screen — which this project has already
    // shipped once, on CarPlay's page.
    _specifiers = specifiers;
    return _specifiers;
}

@end
