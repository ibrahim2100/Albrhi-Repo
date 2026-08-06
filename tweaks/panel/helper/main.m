//
//  albrhipanelhelper
//
//  The one part of Albrhi Panel that runs as root, kept as small as it can be.
//
//  Changing which apps a tweak loads into means editing its filter plist, and those live in
//  a root-owned directory. A preference bundle runs as `mobile` and cannot write there, so
//  this exists — a setuid binary that performs exactly one operation and refuses everything
//  else.
//
//  **A setuid root binary is a security surface, and this one is written on that
//  assumption.** Any process on the device can execute it, not only the panel, so nothing it
//  is told may be trusted:
//
//    - It takes a *filename*, never a path. A name containing '/' or '.' or '..' is
//      rejected outright, so no argument can point outside the one directory it may touch.
//    - The name must match a file that is already in that directory. It cannot create a
//      filter, only edit one that a package put there.
//    - The bundle identifier is checked against a strict character set before it is written.
//    - It edits one key of one dictionary. It cannot delete a file, move one, or write
//      arbitrary content.
//    - The original is copied aside before the first change, so every edit is reversible
//      without the package it came from.
//
//  What it deliberately does not do is take a path, take a plist, or take anything that
//  could be made to name a file elsewhere. Those are how helpers like this become the way
//  into a device.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <unistd.h>
#import <sys/stat.h>

/// The only directory this program may write to, relative to the jailbreak prefix.
static NSString *const kFiltersDirectory = @"Library/MobileSubstrate/DynamicLibraries";

/// Where an untouched copy of each filter is kept, so a change can be undone.
static NSString *const kBackupDirectory = @"Library/Application Support/AlbrhiPanel/original-filters";

/// A bundle identifier, and nothing that is not one.
static BOOL SCIIsBundleIdentifier(NSString *value) {
    if (value.length == 0 || value.length > 256) return NO;

    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"];

    return [value rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

/// A bare filename in the filters directory, and nothing that could leave it.
///
/// Checked rather than sanitised. Stripping dangerous characters out of a path invites the
/// question of whether every dangerous character was thought of; refusing anything that is
/// not already a plain name does not.
static BOOL SCIIsPlainFilterName(NSString *name) {
    if (name.length == 0 || name.length > 255) return NO;
    if ([name rangeOfString:@"/"].location != NSNotFound) return NO;
    if ([name hasPrefix:@"."]) return NO;
    if (![name.pathExtension isEqualToString:@"plist"]) return NO;

    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_+ "];

    return [name rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

/// The jailbreak prefix, taken from where this binary actually is.
///
/// Installed at <prefix>/usr/libexec/albrhipanelhelper, so two components up is the prefix.
/// Rootful gives "/", rootless "/var/jb", and roothide a directory that differs on every
/// device -- which is why this is derived and not chosen from a list.
static NSString *SCIPrefix(void) {
    char buffer[PATH_MAX] = {0};
    uint32_t size = sizeof(buffer);

    // The path this process was executed from. _NSGetExecutablePath can return a relative
    // path, so it is resolved before anything is built on it.
    extern int _NSGetExecutablePath(char *, uint32_t *);
    if (_NSGetExecutablePath(buffer, &size) != 0) return @"/";

    char resolved[PATH_MAX] = {0};
    if (!realpath(buffer, resolved)) return @"/";

    NSString *me = [NSString stringWithUTF8String:resolved];
    return [[[me stringByDeletingLastPathComponent]     // libexec
                  stringByDeletingLastPathComponent]     // usr
                  stringByDeletingLastPathComponent];    // prefix
}

/// Keeps the untouched original, once, before anything is changed.
static void SCIBackupOnce(NSString *filterPath, NSString *name) {
    NSString *directory = [SCIPrefix() stringByAppendingPathComponent:kBackupDirectory];
    NSString *backup = [directory stringByAppendingPathComponent:name];

    NSFileManager *files = [NSFileManager defaultManager];
    if ([files fileExistsAtPath:backup]) return;   // already kept; the first copy is the true one

    [files createDirectoryAtPath:directory withIntermediateDirectories:YES
                      attributes:nil error:NULL];
    [files copyItemAtPath:filterPath toPath:backup error:NULL];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // setuid gives the real uid of the caller and the effective uid of root. The write
        // needs root as the real uid too, or the file ends up owned by mobile.
        setuid(0);
        setgid(0);

        if (geteuid() != 0) {
            fprintf(stderr, "albrhipanelhelper: not root\n");
            return 2;
        }

        if (argc != 5 || strcmp(argv[1], "set") != 0) {
            fprintf(stderr, "usage: albrhipanelhelper set <filter.plist> <bundle.id> <on|off>\n");
            return 64;
        }

        NSString *name = [NSString stringWithUTF8String:argv[2] ?: ""];
        NSString *bundle = [NSString stringWithUTF8String:argv[3] ?: ""];
        NSString *state = [NSString stringWithUTF8String:argv[4] ?: ""];

        if (!SCIIsPlainFilterName(name)) {
            fprintf(stderr, "albrhipanelhelper: refused filter name\n");
            return 65;
        }
        if (!SCIIsBundleIdentifier(bundle)) {
            fprintf(stderr, "albrhipanelhelper: refused bundle identifier\n");
            return 66;
        }

        BOOL turningOn;
        if ([state isEqualToString:@"on"]) turningOn = YES;
        else if ([state isEqualToString:@"off"]) turningOn = NO;
        else { fprintf(stderr, "albrhipanelhelper: state must be on or off\n"); return 67; }

        NSString *directory = [SCIPrefix() stringByAppendingPathComponent:kFiltersDirectory];
        NSString *path = [directory stringByAppendingPathComponent:name];

        // The file must already exist. This edits filters that packages installed; it does
        // not bring new ones into being, which is the difference between a settings helper
        // and a way to make any process load any code.
        NSFileManager *files = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        if (![files fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory) {
            fprintf(stderr, "albrhipanelhelper: no such filter\n");
            return 68;
        }

        NSMutableDictionary *plist =
            [[NSDictionary dictionaryWithContentsOfFile:path] mutableCopy];
        NSMutableDictionary *filter = [plist[@"Filter"] mutableCopy];
        if (!filter) {
            fprintf(stderr, "albrhipanelhelper: filter has no Filter dictionary\n");
            return 69;
        }

        SCIBackupOnce(path, name);

        NSMutableArray *bundles = [(filter[@"Bundles"] ?: @[]) mutableCopy];
        BOOL present = [bundles containsObject:bundle];

        if (turningOn && !present) {
            [bundles addObject:bundle];
        } else if (!turningOn && present) {
            [bundles removeObject:bundle];
        } else {
            return 0;   // already as asked; writing would only churn the file
        }

        // An empty Bundles list with no Executables and no Classes means "load everywhere",
        // which is the opposite of what removing the last app was meant to do. The key is
        // removed instead only when something else still narrows the filter.
        if (bundles.count) {
            filter[@"Bundles"] = bundles;
        } else if (filter[@"Executables"] || filter[@"Classes"]) {
            [filter removeObjectForKey:@"Bundles"];
        } else {
            // Nothing would be left to limit it. Keep an identifier that matches nothing
            // rather than turn the tweak loose on every process on the device.
            filter[@"Bundles"] = @[@"com.albrhi.panel.disabled"];
        }

        plist[@"Filter"] = filter;

        // Written beside the target and renamed over it: a half-written filter is a plist
        // Substrate cannot parse, and it would take the tweak out on the next respring.
        NSString *temporary = [path stringByAppendingString:@".albrhi-new"];
        if (![plist writeToFile:temporary atomically:YES]) {
            fprintf(stderr, "albrhipanelhelper: could not write\n");
            return 70;
        }

        [files setAttributes:@{NSFilePosixPermissions: @0644,
                               NSFileOwnerAccountID: @0,
                               NSFileGroupOwnerAccountID: @0}
                ofItemAtPath:temporary error:NULL];

        if (rename(temporary.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
            [files removeItemAtPath:temporary error:NULL];
            fprintf(stderr, "albrhipanelhelper: could not replace\n");
            return 71;
        }

        return 0;
    }
}
