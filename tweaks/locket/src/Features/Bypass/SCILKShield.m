#import "SCILKShield.h"
#import <string.h>
#import <pthread.h>

///
/// The list. Every entry is here because a real jailbreak check on iOS looks at it.
///
/// Two kinds: exact paths, and prefixes. A prefix catches a whole tree — everything under
/// /Library/MobileSubstrate, every loose file under /var/jb — without naming each file,
/// which matters because the roothide and rootless layouts put the same things in
/// different places and a check walks whatever is there.
///
/// Deliberately not a substring match on "cydia" or "substrate" anywhere in a path: a
/// photo in the app's own container could contain those letters, and lying about a file
/// the app legitimately wrote is how a bypass turns into a crash. Anchored at the start
/// only.
///

static const char *kExactPaths[] = {
    "/Applications/Cydia.app",
    "/Applications/Sileo.app",
    "/Applications/Zebra.app",
    "/Applications/Filza.app",
    "/Applications/blackra1n.app",
    "/Applications/FakeCarrier.app",
    "/Applications/Icy.app",
    "/Applications/IntelliScreen.app",
    "/Applications/MxTube.app",
    "/Applications/RockApp.app",
    "/Applications/SBSettings.app",
    "/Applications/WinterBoard.app",
    "/bin/bash",
    "/bin/sh",
    "/usr/sbin/sshd",
    "/usr/bin/sshd",
    "/usr/libexec/sftp-server",
    "/usr/libexec/ssh-keysign",
    "/usr/bin/ssh",
    "/etc/apt",
    "/etc/ssh/sshd_config",
    "/private/etc/apt",
    "/private/var/lib/apt",
    "/private/var/lib/cydia",
    "/private/var/cache/apt",
    "/private/var/tmp/cydia.log",
    "/private/var/stash",
    "/private/var/mobile/Library/SBSettings/Themes",
    "/Library/dpkg",
    "/var/lib/dpkg",
    "/var/lib/dpkg/status",
    "/var/cache/apt",
    "/usr/libexec/cydia",
    "/usr/libexec/substrate",
    "/usr/lib/libjailbreak.dylib",
    "/usr/lib/libsubstrate.dylib",
    "/usr/lib/substrate",
    "/usr/lib/TweakInject",
    "/usr/lib/libhooker.dylib",
    "/usr/lib/libblackjack.dylib",
    "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
    "/System/Library/LaunchDaemons/com.openssh.sshd.plist",
    "/jb",
    NULL,
};

static const char *kPrefixPaths[] = {
    "/Library/MobileSubstrate",
    "/Library/Frameworks/CydiaSubstrate.framework",
    "/Library/PreferenceBundles/",
    "/Library/PreferenceLoader",
    "/var/jb",
    "/private/var/jb",
    "/var/binpack",
    "/private/var/binpack",
    "/usr/lib/TweakInject/",
    NULL,
};

/// Paths this must never lie about, whatever else matches.
///
/// **`/private/preboot/` was in the prefix list above and it is where iOS keeps its own
/// system content.** From iOS 16 the OS ships as cryptexes: `/System/Cryptexes/OS` is a
/// firmlink to `/private/preboot/Cryptexes/OS`, and dyld resolves system libraries through
/// it. Answering ENOENT for that tree tells the app a system framework does not exist,
/// which is not a failed jailbreak check — it is a launch that dies.
///
/// roothide does put its root under a hash in there, and it is still found: it is marked,
/// and the markers below catch it. A blanket prefix was never needed for that and it took
/// the operating system with it.
///
/// Checked first, so a marker or a prefix cannot override it. A bypass that can deny the
/// system its own files is worse than no bypass.
static const char *kNeverLie[] = {
    "/System/",
    "/private/preboot/Cryptexes/",
    "/private/preboot/active",
    "/usr/lib/dyld",
    "/usr/lib/libSystem",
    "/Library/Caches/com.apple.dyld",
    NULL,
};

/// Names that appear as a component of a roothide jailbreak root. roothide picks a random
/// directory per device, but marks it with these, so a check that finds one anywhere in a
/// path has found the jailbreak. Matched as a path component, not a substring, so a file
/// merely named ".jbroot-something" in the sandbox is not caught.
static const char *kRootMarkers[] = {
    "/.jbroot",
    "/.procursus_strapped",
    "/.installed_unc0ver",
    "/.bootstrapped_electra",
    NULL,
};

static BOOL HasPrefix(const char *path, const char *prefix) {
    return strncmp(path, prefix, strlen(prefix)) == 0;
}

/// Whether a marker appears as a whole path component.
///
/// The comment on the marker list said "as a path component, not a substring" and the code
/// used strstr, which is a substring. A file the app itself wrote called
/// ".jbroot-thumbnail" would have been denied — and lying about a file the app legitimately
/// created is the failure the top of this file warns against. What follows the marker has to
/// be a slash or the end of the path.
static BOOL HasComponent(const char *path, const char *marker) {
    size_t length = strlen(marker);
    for (const char *at = strstr(path, marker); at; at = strstr(at + 1, marker)) {
        char next = at[length];
        if (next == '\0' || next == '/') return YES;
    }
    return NO;
}

BOOL SCILKPathIsJailbreakProbe(const char *path) {
    if (!path || path[0] != '/') return NO;

    for (int i = 0; kNeverLie[i]; i++) {
        if (HasPrefix(path, kNeverLie[i])) return NO;
    }

    for (int i = 0; kExactPaths[i]; i++) {
        if (strcmp(path, kExactPaths[i]) == 0) return YES;
    }
    for (int i = 0; kPrefixPaths[i]; i++) {
        if (HasPrefix(path, kPrefixPaths[i])) return YES;
    }
    for (int i = 0; kRootMarkers[i]; i++) {
        if (HasComponent(path, kRootMarkers[i])) return YES;
    }
    return NO;
}

BOOL SCILKWriteIsSandboxProbe(const char *path, const char *mode) {
    if (!path || !mode) return NO;

    // Only writes. A read is covered by the path list above.
    if (!strpbrk(mode, "wa+")) return NO;

    // The same allowlist. This function denies whole trees by prefix, so it needs it more
    // than the path list does.
    for (int i = 0; kNeverLie[i]; i++) {
        if (HasPrefix(path, kNeverLie[i])) return NO;
    }

    // Inside the app's own container is fine — that is where it is allowed to write, and
    // where it does its real work. The container is under /var/mobile/Containers or the
    // /private mirror of it; anything else at the system root is somewhere a sandboxed app
    // cannot reach, so a write probe there is a jailbreak test and denying it is free.
    if (strstr(path, "/Containers/")) return NO;
    if (strstr(path, "/Library/Caches/")) return NO;
    if (strstr(path, "tmp/")) return NO;

    static const char *systemRoots[] = {
        "/private/", "/var/", "/usr/", "/bin/", "/etc/", "/Library/", "/Applications/", NULL
    };
    for (int i = 0; systemRoots[i]; i++) {
        if (HasPrefix(path, systemRoots[i])) return YES;
    }
    return NO;
}

BOOL SCILKSchemeIsJailbreakProbe(NSString *scheme) {
    if (!scheme.length) return NO;

    static NSSet *schemes = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        schemes = [NSSet setWithArray:@[
            @"cydia", @"sileo", @"zbra", @"zebra", @"filza", @"undecimus",
            @"activator", @"apt-repo", @"postbox", @"xina", @"santander",
        ]];
    });
    return [schemes containsObject:scheme.lowercaseString];
}

BOOL SCILKEnvIsJailbreakProbe(const char *name) {
    if (!name) return NO;

    static const char *vars[] = {
        "DYLD_INSERT_LIBRARIES",
        "DYLD_FALLBACK_LIBRARY_PATH",
        "DYLD_FALLBACK_FRAMEWORK_PATH",
        "_MSSafeMode",
        "_SubstrateInsertLibraries",
        NULL,
    };
    for (int i = 0; vars[i]; i++) {
        if (strcmp(name, vars[i]) == 0) return YES;
    }
    return NO;
}


///
/// The tally, for the status screen. A lock rather than a queue: the filesystem hooks that
/// call this are answered synchronously with a caller waiting, and the critical section is
/// a couple of integer bumps.
///
static pthread_mutex_t _lock = PTHREAD_MUTEX_INITIALIZER;
static NSUInteger _total = 0;
static NSMutableDictionary<NSString *, NSNumber *> *_byKind = nil;
static NSMutableArray<NSString *> *_recent = nil;

/// How many notes still get a written line. After this, only the counters move.
///
/// Every caller of this is a hook on stat, lstat, access or fopen, and Locket is a Flutter
/// app: the Dart runtime asks the filesystem thousands of times a second. Formatting a
/// string and scanning a forty-element array on each one is work done inside libc, on
/// whatever thread called it, for a list that stopped changing after the first few seconds.
///
/// The counters are two integer bumps and stay honest for the whole session. The tail of
/// examples is for a human reading a screen and is complete long before this cap.
static const NSUInteger kDetailBudget = 400;
static NSUInteger _detailsWritten = 0;

void SCILKNoteIntercept(NSString *kind, NSString *detail) {
    if (!kind.length) return;

    pthread_mutex_lock(&_lock);

    if (!_byKind) {
        _byKind = [NSMutableDictionary dictionary];
        _recent = [NSMutableArray array];
    }

    _total++;
    _byKind[kind] = @(_byKind[kind].unsignedIntegerValue + 1);

    // A short tail of what was caught, newest first, for the screen. Deduplicated: a check
    // that runs every second would otherwise fill the list with one line, and the point of
    // the list is variety, not volume.
    if (_detailsWritten < kDetailBudget) {
        _detailsWritten++;

        NSString *line = detail.length ? [NSString stringWithFormat:@"%@ · %@", kind, detail] : kind;
        [_recent removeObject:line];
        [_recent insertObject:line atIndex:0];
        while (_recent.count > 40) [_recent removeLastObject];
    }

    pthread_mutex_unlock(&_lock);
}

NSUInteger SCILKInterceptCount(void) {
    pthread_mutex_lock(&_lock);
    NSUInteger total = _total;
    pthread_mutex_unlock(&_lock);
    return total;
}

NSDictionary<NSString *, NSNumber *> *SCILKInterceptsByKind(void) {
    pthread_mutex_lock(&_lock);
    NSDictionary *snapshot = [_byKind copy] ?: @{};
    pthread_mutex_unlock(&_lock);
    return snapshot;
}

NSArray<NSString *> *SCILKRecentIntercepts(void) {
    pthread_mutex_lock(&_lock);
    NSArray *snapshot = [_recent copy] ?: @[];
    pthread_mutex_unlock(&_lock);
    return snapshot;
}
