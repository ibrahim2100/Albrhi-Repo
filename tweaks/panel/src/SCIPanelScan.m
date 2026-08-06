#import "SCIPanelScan.h"
#import <objc/runtime.h>

///
/// Reading the device rather than being told about it.
///
/// Two sources, joined on the app:
///
///   <prefix>/Library/MobileSubstrate/DynamicLibraries/*.plist   what each tweak targets
///   LSApplicationWorkspace                                      what is installed
///
/// A filter names its targets in three ways and they are not interchangeable. `Bundles`
/// holds bundle identifiers. `Executables` holds the name of the binary inside the app,
/// which is how DLEasy catches every build of WhatsApp including the one whose executable
/// is spelled in Arabic. `Classes` names a class that must exist in the process, which
/// cannot be answered from outside it at all — so it is recorded and shown, never guessed
/// at.
///

/// Private, and the only way to ask what is installed. Declared rather than imported:
/// the header is not in the SDK, and a declaration that is wrong fails to compile, while
/// -performSelector: with a wrong name fails on the phone.
@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *bundleURL;
@property (nonatomic, readonly) NSString *bundleExecutable;
@property (nonatomic, readonly) NSString *applicationType;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end


@implementation SCIPanelTweak

- (BOOL)targetsSystem {
    for (NSString *bundle in self.bundles) {
        if ([bundle isEqualToString:@"com.apple.springboard"] ||
            [bundle isEqualToString:@"com.apple.preferences"]) {
            return YES;
        }
    }
    return NO;
}

@end


@implementation SCIPanelApp
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

+ (NSArray<SCIPanelTweak *> *)installedTweaks {
    NSString *directory = [[self jailbreakPrefix]
        stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries"];

    NSFileManager *files = [NSFileManager defaultManager];
    NSArray<NSString *> *names = [files contentsOfDirectoryAtPath:directory error:NULL];
    if (!names.count) return @[];

    NSMutableArray<SCIPanelTweak *> *out = [NSMutableArray array];

    for (NSString *name in names) {
        if (![name.pathExtension isEqualToString:@"plist"]) continue;

        NSString *filter = [directory stringByAppendingPathComponent:name];
        NSString *stem = name.stringByDeletingPathExtension;
        NSString *dylib = [directory stringByAppendingPathComponent:
            [stem stringByAppendingPathExtension:@"dylib"]];

        // A filter with no dylib beside it is a leftover from a removed package, and
        // listing it as an active tweak would be a lie.
        if (![files fileExistsAtPath:dylib]) continue;

        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:filter];
        NSDictionary *rules = plist[@"Filter"];
        if (![rules isKindOfClass:[NSDictionary class]]) continue;

        SCIPanelTweak *tweak = [[SCIPanelTweak alloc] init];
        tweak.name = stem;
        tweak.dylibPath = dylib;
        tweak.filterPath = filter;

        // Lowercased once, here, because bundle identifiers are matched case-insensitively
        // by Substrate and comparing them any other way finds nothing on some devices and
        // everything on others.
        NSMutableArray *bundles = [NSMutableArray array];
        for (id entry in rules[@"Bundles"]) {
            if ([entry isKindOfClass:[NSString class]]) [bundles addObject:[entry lowercaseString]];
        }
        tweak.bundles = bundles;

        NSMutableArray *executables = [NSMutableArray array];
        for (id entry in rules[@"Executables"]) {
            if ([entry isKindOfClass:[NSString class]]) [executables addObject:entry];
        }
        tweak.executables = executables;

        NSMutableArray *classes = [NSMutableArray array];
        for (id entry in rules[@"Classes"]) {
            if ([entry isKindOfClass:[NSString class]]) [classes addObject:entry];
        }
        tweak.classes = classes;

        tweak.size = [[files attributesOfItemAtPath:dylib error:NULL] fileSize];

        [out addObject:tweak];
    }

    [out sortUsingComparator:^NSComparisonResult(SCIPanelTweak *a, SCIPanelTweak *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return out;
}

/// Whether a tweak's filter names this app.
///
/// Classes are deliberately not consulted. A Classes filter means "load me wherever this
/// class exists", and whether it exists in an app cannot be decided without being inside
/// that app. Counting it as a match would overstate, and ignoring the tweak entirely would
/// hide it — so a Classes-only filter matches nothing here and is shown on its own terms.
static BOOL SCITweakTargetsApp(SCIPanelTweak *tweak, SCIPanelApp *app) {
    if ([tweak.bundles containsObject:app.bundleIdentifier.lowercaseString]) return YES;

    if (app.executable.length && [tweak.executables containsObject:app.executable]) return YES;

    return NO;
}

+ (NSArray<SCIPanelApp *> *)allApps {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return @[];

    LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
    NSArray<LSApplicationProxy *> *installed = [workspace allInstalledApplications];
    if (!installed.count) return @[];

    NSArray<SCIPanelTweak *> *tweaks = [self installedTweaks];
    NSMutableArray<SCIPanelApp *> *out = [NSMutableArray array];

    for (LSApplicationProxy *proxy in installed) {
        // System applications are excluded: they are not what anyone opens this to manage,
        // and including them buries the twenty apps that are.
        NSString *type = proxy.applicationType;
        if ([type isEqualToString:@"System"] || [type isEqualToString:@"Internal"]) continue;

        SCIPanelApp *app = [[SCIPanelApp alloc] init];
        app.bundleIdentifier = proxy.applicationIdentifier ?: @"";
        app.name = proxy.localizedName.length ? proxy.localizedName : app.bundleIdentifier;
        app.executable = proxy.bundleExecutable;

        NSMutableArray<SCIPanelTweak *> *matched = [NSMutableArray array];
        for (SCIPanelTweak *tweak in tweaks) {
            if (SCITweakTargetsApp(tweak, app)) [matched addObject:tweak];
        }
        app.tweaks = matched;

        [out addObject:app];
    }

    // Most-affected first, then by name. The question the page answers is "what is being
    // changed", so the app with five tweaks in it belongs at the top.
    [out sortUsingComparator:^NSComparisonResult(SCIPanelApp *a, SCIPanelApp *b) {
        if (a.tweaks.count != b.tweaks.count) {
            return a.tweaks.count > b.tweaks.count ? NSOrderedAscending : NSOrderedDescending;
        }
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return out;
}

+ (NSArray<SCIPanelApp *> *)affectedApps {
    NSMutableArray<SCIPanelApp *> *out = [NSMutableArray array];
    for (SCIPanelApp *app in [self allApps]) {
        if (app.tweaks.count) [out addObject:app];
    }
    return out;
}

@end
