#import "SCIPanelScan.h"
#import "shared/src/SCIKVC.h"

///
/// Reading the device rather than being told about it.
///
/// Each Albrhi tweak announces the app it patches in a filter plist beside its dylib. That
/// file is the honest record: a panel that hard-coded "Instagram and YouTube" would be wrong
/// the day a third tweak shipped, and wrong in the direction that hides a feature somebody
/// installed.
///

/// Private, and the only way to ask what is installed. Declared rather than imported: the
/// header is not in the SDK, and a declaration that is wrong fails to compile, while
/// -performSelector: with a wrong name fails on the phone.
@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *bundleExecutable;
@property (nonatomic, readonly) NSString *shortVersionString;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end

/// How Settings itself draws an app's icon.
///
/// Private, and asked for by -respondsToSelector: rather than called on faith. A row with
/// no picture is a smaller loss than a page that will not load, and this is the one call
/// here that a future iOS could remove.
@interface UIImage (SCIPanelIcons)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier
                                                format:(int)format
                                                 scale:(CGFloat)scale;
@end


@implementation SCIPanelEntry

/// A tweak can be verified against several versions, and the Instagram one is: 410, 439
/// and 441 from a single build. So the declaration is a list, and a match is any entry.
///
/// Compared by prefix, on whole components. "441" has to match the "441.0.3" a phone
/// reports, or every row would read as a mismatch and the section would be noise. But
/// prefix alone would make "44" match "441", so the character after the match must be a
/// dot or nothing.
- (BOOL)runsTestedVersion {
    if (!self.appVersion.length || !self.testedVersion.length) return NO;

    for (NSString *raw in [self.testedVersion componentsSeparatedByString:@","]) {
        NSString *tested = [raw stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        if (!tested.length) continue;

        if ([self.appVersion isEqualToString:tested]) return YES;
        if ([self.appVersion hasPrefix:[tested stringByAppendingString:@"."]]) return YES;
    }
    return NO;
}

@end


@implementation SCIPanelScan

+ (NSString *)jailbreakPrefix {
    static NSString *prefix = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // .../Library/PreferenceBundles/AlbrhiPanel.bundle -> three components up.
        NSString *here = [[NSBundle bundleForClass:self] bundlePath];
        NSString *up = [[[here stringByDeletingLastPathComponent]
                                stringByDeletingLastPathComponent]
                                stringByDeletingLastPathComponent];

        // A sanity check rather than blind trust: if we are somewhere unexpected -- built
        // into a test harness, say -- root is a better guess than a path three levels above
        // wherever that was.
        BOOL plausible = [[NSFileManager defaultManager]
            fileExistsAtPath:[up stringByAppendingPathComponent:@"Library/MobileSubstrate"]];

        prefix = plausible ? up : @"/";
    });
    return prefix;
}

+ (NSString *)installedSuiteVersion {
    // Read once per launch of Settings, and that is enough.
    //
    // dpkg's status file is a few megabytes of every package on the device, and this is
    // asked for while a page is being laid out -- once for the header and once for the
    // About row. Parsing it twice on the main thread for a string that cannot change
    // while this page is open is work for nothing: the panel's own after-install step
    // kills Preferences, so a new version always arrives in a new process.
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The combined package first and the panel's own second, so a device that
        // installed the components separately still gets a true answer rather than none.
        cached = [self installedVersionForPackages:@[@"com.albrhi", @"com.albrhi.panel"]];
    });
    return cached;
}

+ (NSString *)installedVersionForPackages:(NSArray<NSString *> *)wanted {
    NSString *prefix = [self jailbreakPrefix];

    // Where each jailbreak keeps it. The prefixed path first, because that is where a
    // rootless or roothide install puts it, and /var/lib last for a rootful device.
    NSArray<NSString *> *candidates = @[
        [prefix stringByAppendingPathComponent:@"Library/dpkg/status"],
        [prefix stringByAppendingPathComponent:@"var/lib/dpkg/status"],
        @"/var/lib/dpkg/status"
    ];

    for (NSString *path in candidates) {
        NSString *status = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:NULL];
        if (!status.length) continue;

        for (NSString *package in wanted) {
            // dpkg's status file is stanzas separated by a blank line, so the version
            // belonging to a package is the first Version: after its Package: line and
            // before the stanza ends. Scanning the whole file for "Version:" would return
            // whichever package happened to come first.
            //
            // The name is matched with the newlines around it, so looking for com.albrhi
            // cannot land on com.albrhi.panel. And the first stanza in the file has no
            // newline in front of it, so that one is checked separately -- a package that
            // happened to be installed first would otherwise never be found, which is a
            // bug that would have shown up on one device in however many and looked like
            // the read failing.
            NSString *label = [NSString stringWithFormat:@"Package: %@\n", package];
            NSUInteger start;

            if ([status hasPrefix:label]) {
                start = label.length;
            } else {
                NSRange found = [status rangeOfString:
                    [@"\n" stringByAppendingString:label]];
                if (found.location == NSNotFound) continue;
                start = NSMaxRange(found);
            }

            NSString *rest = [status substringFromIndex:start];
            NSRange end = [rest rangeOfString:@"\n\n"];
            if (end.location != NSNotFound) rest = [rest substringToIndex:end.location];

            for (NSString *line in [rest componentsSeparatedByString:@"\n"]) {
                if (![line hasPrefix:@"Version: "]) continue;

                NSString *version = [[line substringFromIndex:9]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (version.length) return version;
            }
        }
    }

    return nil;
}

/// The icon the home screen uses for an app, at a size a settings row wants.
///
/// Format 2 is the 62-point artwork. Asked for at the screen's own scale so it is the
/// image iOS already has rather than one scaled up from a smaller cache.
+ (UIImage *)iconFor:(NSString *)identifier {
    if (!identifier.length) return nil;

    SEL selector = @selector(_applicationIconImageForBundleIdentifier:format:scale:);
    if (![UIImage respondsToSelector:selector]) return nil;

    @try {
        return [UIImage _applicationIconImageForBundleIdentifier:identifier
                                                           format:2
                                                            scale:[UIScreen mainScreen].scale];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

/// bundle identifier -> the name the device shows for it.
+ (void)readInstalled:(NSMutableDictionary<NSString *, NSString *> *)names
           executables:(NSMutableDictionary<NSString *, NSString *> *)executables
              versions:(NSMutableDictionary<NSString *, NSString *> *)versions {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return;

    for (LSApplicationProxy *proxy in [[workspaceClass defaultWorkspace] allInstalledApplications]) {
        NSString *identifier = proxy.applicationIdentifier;
        if (!identifier.length) continue;

        names[identifier.lowercaseString] = proxy.localizedName.length
            ? proxy.localizedName : identifier;

        // Asked for by more than one name.
        //
        // shortVersionString is the marketing version and the one to show, and it is not
        // always there -- a proxy for a sideloaded or system app can carry only the build
        // number. Taking the first non-empty answer is the difference between a row that
        // says 410.1.0 and a section that does not appear at all, which is what the first
        // version of this did on the developer's own phone.
        for (NSString *name in @[@"shortVersionString", @"bundleVersion", @"versionString"]) {
            if (![proxy respondsToSelector:NSSelectorFromString(name)]) continue;

            id answer = nil;
            @try { answer = SCISafeValueForKey(proxy, name); } @catch (__unused NSException *e) { }

            if ([answer isKindOfClass:[NSString class]] && [answer length]) {
                versions[identifier.lowercaseString] = answer;
                break;
            }
        }

        // So an Executables filter can be resolved to the app it means. Two apps can
        // share an executable name; the first wins and the second keeps its own row
        // through Bundles if it has one.
        NSString *executable = proxy.bundleExecutable;
        if (executable.length && !executables[executable]) executables[executable] = identifier;
    }
}

+ (NSArray<SCIPanelEntry *> *)entries {
    NSString *directory = [[self jailbreakPrefix]
        stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries"];

    NSFileManager *files = [NSFileManager defaultManager];
    NSArray<NSString *> *contents = [files contentsOfDirectoryAtPath:directory error:NULL];
    if (!contents.count) return @[];

    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *executableOwners = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *versions = [NSMutableDictionary dictionary];
    [self readInstalled:names executables:executableOwners versions:versions];

    NSMutableArray<SCIPanelEntry *> *out = [NSMutableArray array];

    for (NSString *fileName in contents) {
        if (![fileName.pathExtension isEqualToString:@"plist"]) continue;

        NSString *stem = fileName.stringByDeletingPathExtension;

        // Ours and nothing else. Matched on the dylib's name because that is what this
        // project controls -- the package id lives in a control file the phone does not
        // keep, and the bundle identifiers are the apps' rather than ours.
        if (![stem hasPrefix:@"Albrhi"]) continue;

        NSString *dylib = [directory stringByAppendingPathComponent:
            [stem stringByAppendingPathExtension:@"dylib"]];

        // A filter with no dylib beside it is a leftover from a removed package, and
        // showing a switch for it would offer control over something that is not there.
        if (![files fileExistsAtPath:dylib]) continue;

        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:
            [directory stringByAppendingPathComponent:fileName]];
        NSDictionary *filter = plist[@"Filter"];
        if (![filter isKindOfClass:[NSDictionary class]]) continue;

        // Two reasons a filter is here and does not belong on this page.
        //
        // A second dylib belonging to a tweak the panel already has a row for.
        // AlbrhiCPApp filters on com.apple.UIKit/UIKitCore -- MobileSubstrate's
        // Bundles idiom for "every app that draws a window" -- and without this,
        // those two framework identifiers would themselves become rows, exactly the
        // "Camera"/"SpringBoard" mistake SCIPanelGroupIdentifier exists to fix, just
        // for library names instead of app bundle identifiers this time.
        //
        // And a tweak that is simply not Albrhi's. Albrhi NextUp and Albrhi Watch are separate
        // packages with Settings rows of their own; this page is for the social-app tweaks the
        // suite ships. Without the key their filters would each become several rows here named
        // for the processes they inject into, which is the "Camera"/"SpringBoard" mistake again
        // arriving from the far side of a page that has moved out of this bundle.
        if ([plist[@"SCIPanelHidden"] boolValue]) continue;

        unsigned long long size =
            [[files attributesOfItemAtPath:dylib error:NULL] fileSize];

        // A tweak that names its own group collapses to one row regardless of how many
        // Bundles or Executables targets its filter carries -- Albrhi CarPlay is one
        // filter naming two processes (SpringBoard, Camera) that is one feature, not two
        // apps this project patches. Declared in the filter plist itself, the same place
        // SCITestedVersion already is, rather than hard-coded here: this file should not
        // have to know CarPlay's identifier to treat it correctly.
        NSString *groupIdentifier = plist[@"SCIPanelGroupIdentifier"];
        NSString *groupName = plist[@"SCIPanelGroupName"];
        NSString *detailController = plist[@"SCIPanelDetailController"];

        if ([groupIdentifier isKindOfClass:[NSString class]] && groupIdentifier.length) {
            SCIPanelEntry *entry = [[SCIPanelEntry alloc] init];
            entry.tweakName = stem;
            entry.bundleIdentifier = groupIdentifier;
            entry.appName = ([groupName isKindOfClass:[NSString class]] && groupName.length)
                ? groupName : groupIdentifier;
            entry.size = size;

            // Not a real installed app, so there is no app to be missing -- the row
            // exists whenever the tweak that declared it is installed, which it is: this
            // loop only ever runs for a filter beside a dylib that is actually there.
            entry.appInstalled = YES;

            if ([detailController isKindOfClass:[NSString class]] && detailController.length) {
                entry.detailControllerClassName = detailController;
            }

            //
            // **A group that names exactly one app is still about that app, and should look it.**
            //
            // The grouped row exists because a filter naming SpringBoard and Camera is one feature
            // rather than two apps -- so those rows get a drawn badge, since a group identifier
            // names a tweak and no icon can be resolved from it. A filter naming one real app is
            // the opposite case: Albrhi for Spotify is collapsed only because it wants a page, and
            // a music-note glyph where Spotify's own mark belongs makes it the odd row in a list
            // read by eye rather than by name.
            //
            NSArray *bundles = filter[@"Bundles"];
            if ([bundles isKindOfClass:[NSArray class]] && bundles.count == 1
                    && [bundles.firstObject isKindOfClass:[NSString class]]) {
                entry.appIcon = [self iconFor:bundles.firstObject];
            }

            [out addObject:entry];
            continue;
        }

        // Bundles is what most filters use. Executables is read too, because a future
        // Albrhi tweak written that way would otherwise produce no row at all -- the app
        // would simply not appear, with nothing to say why, which is exactly the
        // silent-omission failure this project keeps having to fix.
        NSMutableArray *targets = [NSMutableArray array];
        for (id candidate in filter[@"Bundles"]) {
            if ([candidate isKindOfClass:[NSString class]]) [targets addObject:candidate];
        }
        for (id candidate in filter[@"Executables"]) {
            if (![candidate isKindOfClass:[NSString class]]) continue;

            // An executable name is not a bundle identifier, so the app it belongs to has
            // to be found by asking the device rather than by matching the string.
            NSString *identifier = executableOwners[candidate];
            if (identifier && ![targets containsObject:identifier]) [targets addObject:identifier];
        }

        for (id candidate in targets) {
            if (![candidate isKindOfClass:[NSString class]]) continue;

            SCIPanelEntry *entry = [[SCIPanelEntry alloc] init];
            entry.tweakName = stem;
            entry.bundleIdentifier = candidate;
            entry.size = size;

            NSString *known = names[[candidate lowercaseString]];
            entry.appInstalled = (known != nil);
            entry.appName = known ?: candidate;
            entry.appVersion = versions[[candidate lowercaseString]];

            // Declared by the tweak, in its own filter file, beside the app it names.
            //
            // Not a table in this panel. A hard-coded "Instagram 410.1.0, YouTube 21.30.5"
            // here would be wrong the day a tweak is retested and nobody remembered to
            // come back — and wrong in the direction that quietly misinforms. The tweak
            // knows what it was built against; it is the only thing that does.
            id declared = plist[@"SCITestedVersion"];
            if ([declared isKindOfClass:[NSString class]]) entry.testedVersion = declared;

            if (entry.appInstalled) entry.appIcon = [self iconFor:candidate];

            [out addObject:entry];
        }
    }

    // Installed apps first, then by name. A tweak whose app is not on the phone is still
    // worth showing -- it says why nothing is happening -- but it belongs below the ones
    // that can actually do something.
    [out sortUsingComparator:^NSComparisonResult(SCIPanelEntry *a, SCIPanelEntry *b) {
        if (a.appInstalled != b.appInstalled) return a.appInstalled ? NSOrderedAscending : NSOrderedDescending;
        return [a.appName localizedCaseInsensitiveCompare:b.appName];
    }];
    return out;
}

@end
