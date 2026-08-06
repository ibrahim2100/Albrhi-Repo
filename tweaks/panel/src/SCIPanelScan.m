#import "SCIPanelScan.h"

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
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end


@implementation SCIPanelEntry
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

/// bundle identifier -> the name the device shows for it.
+ (void)readInstalled:(NSMutableDictionary<NSString *, NSString *> *)names
           executables:(NSMutableDictionary<NSString *, NSString *> *)executables {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return;

    for (LSApplicationProxy *proxy in [[workspaceClass defaultWorkspace] allInstalledApplications]) {
        NSString *identifier = proxy.applicationIdentifier;
        if (!identifier.length) continue;

        names[identifier.lowercaseString] = proxy.localizedName.length
            ? proxy.localizedName : identifier;

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
    [self readInstalled:names executables:executableOwners];

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

        unsigned long long size =
            [[files attributesOfItemAtPath:dylib error:NULL] fileSize];

        // Bundles is what both current filters use. Executables is read too, because a
        // future Albrhi tweak written that way would otherwise produce no row at all --
        // the app would simply not appear, with nothing to say why, which is exactly the
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
