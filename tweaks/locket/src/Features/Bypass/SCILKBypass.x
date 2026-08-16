#import <UIKit/UIKit.h>
#import <sys/stat.h>
#import <errno.h>
#import <stdio.h>
#import <unistd.h>
#import <stdlib.h>
#import "SCILKBypass.h"
#import "SCILKShield.h"
#import "SCILog.h"

///
/// The hooks. Each one is thin: it asks SCILKShield whether the thing being looked at is a
/// jailbreak probe, and if so answers the way an unmodified phone would. If not, it does
/// exactly what the app asked. Nothing here decides what a jailbreak path *is* — that is
/// all in SCILKShield, so the rule "only lie about these, pass everything else through" is
/// enforced in one place.
///
/// ## Everything is in a group, and that is the point
///
/// Logos will install an ungrouped hook by itself, at load, before this tweak's own
/// constructor runs — which would install the filesystem hooks even when the panel has
/// switched the tweak off for Locket. Grouping every hook and initialising the groups by
/// hand, from the constructor and only after the panel switch is consulted, is what makes
/// "off" actually mean off.
///
/// ## Why the C functions and not only the Objective-C ones
///
/// The three things doing the checking — AppsFlyer, OneSignal, and Locket's own Flutter
/// code — do not all go through `-[NSFileManager fileExistsAtPath:]`. The native and
/// Flutter layers call `stat`, `access` and `fopen` straight through libc. Hooking only the
/// Foundation call would leave those untouched, which is the difference between a bypass
/// that works and one that appears to. `%hookf` rebinds the C function itself.
///

///
/// Not built into the self-contained sideload dylib.
///
/// Every %hookf below compiles to a call to MSHookFunction -- Substrate's own
/// C-function hooking primitive, and a genuinely different mechanism from the
/// MSHookMessageEx that SCISubstrateShim.m already replaces for Objective-C
/// hooks. Reimplementing function-level hooking without Substrate (fishhook-
/// style symbol rebinding, or Apple's own DYLD_INTERPOSE) is real systems work
/// this project has not built and verified on a device yet, so rather than link
/// it in unverified, the whole file compiles to a no-op stub in that build and
/// the moment-saving feature -- which only ever uses ordinary %hook, not
/// %hookf -- still ships standalone. The jailbreak packages are unaffected:
/// this is exactly what they had, unchanged.
///
#ifdef SCI_SELFCONTAINED

void SCILKInstallBypass(void) {
    SCILogV(@"jailbreak-detection bypass not built into the self-contained dylib");
}

#else

%group Core

#pragma mark - libc

%hookf(int, stat, const char *path, struct stat *buf) {
    if (path && SCILKPathIsJailbreakProbe(path)) {
        SCILKNoteIntercept(@"file", @(path));
        errno = ENOENT;
        return -1;
    }
    return %orig;
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (path && SCILKPathIsJailbreakProbe(path)) {
        SCILKNoteIntercept(@"file", @(path));
        errno = ENOENT;
        return -1;
    }
    return %orig;
}

%hookf(int, access, const char *path, int mode) {
    if (path && SCILKPathIsJailbreakProbe(path)) {
        SCILKNoteIntercept(@"file", @(path));
        errno = ENOENT;
        return -1;
    }
    return %orig;
}

%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (path && (SCILKPathIsJailbreakProbe(path) || SCILKWriteIsSandboxProbe(path, mode))) {
        SCILKNoteIntercept(@"file", @(path));
        errno = ENOENT;
        return NULL;
    }
    return %orig;
}

// Deliberately not `open`. It is variadic — open(path, flags, mode) — and a two-argument
// hook would drop the mode on every legitimate O_CREAT the app makes elsewhere, corrupting
// real file creation to defeat a check that stat and fopen already cover. Not worth it.

%hookf(char *, getenv, const char *name) {
    if (name && SCILKEnvIsJailbreakProbe(name)) {
        SCILKNoteIntercept(@"env", @(name));
        return NULL;
    }
    return %orig;
}

#pragma mark - Foundation

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (path && SCILKPathIsJailbreakProbe(path.fileSystemRepresentation)) {
        SCILKNoteIntercept(@"file", path);
        return NO;
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (path && SCILKPathIsJailbreakProbe(path.fileSystemRepresentation)) {
        SCILKNoteIntercept(@"file", path);
        if (isDirectory) *isDirectory = NO;
        return NO;
    }
    return %orig;
}

%end

#pragma mark - UIKit

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if ([url isKindOfClass:[NSURL class]] && SCILKSchemeIsJailbreakProbe(url.scheme)) {
        SCILKNoteIntercept(@"scheme", url.scheme);
        return NO;
    }
    return %orig;
}

%end

%end  // group Core


#pragma mark - OneSignal

// Its own group, initialised only if the class is present. OneSignal's check returns one
// BOOL and the app trusts it, so answering NO here is the whole job. The filesystem hooks
// already defeat AppsFlyer and Locket's Flutter checks, which do not expose a single answer
// to hook — they read the paths, and the paths now read clean.
%group OneSignal

%hook OneSignalJailbreakDetection

+ (BOOL)isJailbroken {
    SCILKNoteIntercept(@"onesignal", nil);
    return NO;
}

%end

%end  // group OneSignal


void SCILKInstallBypass(void) {
    %init(Core);
    SCILogV(@"filesystem, environment and scheme hooks installed");

    if (NSClassFromString(@"OneSignalJailbreakDetection")) {
        %init(OneSignal);
        SCILogV(@"OneSignalJailbreakDetection hooked");
    } else {
        SCILogV(@"OneSignalJailbreakDetection not in this build — the libc hooks still cover it");
    }
}

#endif  /* SCI_SELFCONTAINED */
