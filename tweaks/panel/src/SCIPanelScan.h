//
//  SCIPanelScan.h
//  Albrhi Panel
//
//  What is installed, and what gets injected into it.
//
//  Every jailbreak tweak on the device announces its targets in a plist beside its dylib:
//  a Filter with Bundles, Executables or Classes. Those files are the only honest record of
//  what loads where — a package manager knows what is *installed*, and nothing on the phone
//  tells you what is *active in which app*. This reads them, reads the installed apps, and
//  puts the two together.
//
//  **Read-only, and deliberately so.** Nothing here writes, moves or deletes anything. The
//  panel earns the right to change filters by first proving it can describe them correctly.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One tweak's dylib and the filter beside it.
@interface SCIPanelTweak : NSObject
/// The dylib's file name without extension — "Albrhi", "DLEasy".
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *dylibPath;
@property (nonatomic, copy) NSString *filterPath;

/// Straight out of the filter, lowercased for matching.
@property (nonatomic, copy) NSArray<NSString *> *bundles;
@property (nonatomic, copy) NSArray<NSString *> *executables;
@property (nonatomic, copy) NSArray<NSString *> *classes;

/// Bytes on disk, so the list can say which tweak is the heavy one.
@property (nonatomic, assign) unsigned long long size;

/// Whether this filter names SpringBoard or Preferences rather than an app.
@property (nonatomic, readonly) BOOL targetsSystem;
@end


/// One installed application, and the tweaks whose filters name it.
@interface SCIPanelApp : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *name;
/// The executable's own name, which is what a Filter's Executables list matches on.
@property (nonatomic, copy, nullable) NSString *executable;
@property (nonatomic, strong) NSArray<SCIPanelTweak *> *tweaks;
@end


@interface SCIPanelScan : NSObject

/// Where the jailbreak put everything.
///
/// Derived from this bundle's own path rather than guessed. Rootful is "/", rootless is
/// "/var/jb", and roothide is a different random directory on every device — so a list of
/// candidates would be wrong on roothide by design. We are installed at
/// <prefix>/Library/PreferenceBundles/AlbrhiPanel.bundle, and walking three components up
/// from ourselves gives the prefix on all three without knowing which one we are on.
+ (NSString *)jailbreakPrefix;

/// Every tweak with a filter plist, sorted by name. Empty when the directory is unreadable,
/// which is an answer and not an error — a sideloaded device has no such directory at all.
+ (NSArray<SCIPanelTweak *> *)installedTweaks;

/// Every installed app that at least one tweak names, plus how many name it.
///
/// Apps nothing targets are left out: a list of every app on the phone is a list nobody
/// scrolls, and the question this page answers is "what is being changed".
+ (NSArray<SCIPanelApp *> *)affectedApps;

/// Every installed app, for the screen that has a search field.
+ (NSArray<SCIPanelApp *> *)allApps;

@end

NS_ASSUME_NONNULL_END
