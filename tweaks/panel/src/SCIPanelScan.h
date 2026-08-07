//
//  SCIPanelScan.h
//  Albrhi Panel
//
//  Which of Albrhi's tweaks are installed, and which app each one belongs to.
//
//  The panel is Albrhi's own control panel and nothing else. An earlier version listed every
//  tweak on the device and offered to edit other developers' filter files through a root
//  helper — which was a different product answering a question nobody asked. It was removed
//  rather than left switched off: a setuid root binary shipped for a feature that is not
//  wanted is pure risk with no return.
//
//  What is left is the shape DLEasy has, for the same reason it has it: one developer's
//  tweak, its settings in the iOS Settings app, and a switch per app it supports. Apps
//  Albrhi does not touch are not listed, because a list of sixty apps to find the two that
//  matter is not a list.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// One Albrhi tweak, and the app it patches.
@interface SCIPanelEntry : NSObject
/// The dylib's file name without extension — "Albrhi", "AlbrhiYT".
@property (nonatomic, copy) NSString *tweakName;
@property (nonatomic, copy) NSString *bundleIdentifier;
/// The app's own name as the device shows it, or the identifier when it is not installed.
@property (nonatomic, copy) NSString *appName;
/// Whether the app the tweak targets is actually on this device.
@property (nonatomic, assign) BOOL appInstalled;
@property (nonatomic, assign) unsigned long long size;

/// The app's own icon, as the home screen draws it. Nil when the app is not installed.
@property (nonatomic, strong, nullable) UIImage *appIcon;

/// What version of the app is on this phone, and what version the tweak was built
/// against. Either may be nil: the first when the app is not installed, the second when
/// the tweak's filter file does not say.
///
/// Both are shown because the interesting fact is the *comparison*. "Tested on 410.1.0"
/// alone tells nobody anything; "you have 412.0.0, tested on 410.1.0" is the answer to
/// the question people actually arrive with, which is why something stopped working.
@property (nonatomic, copy, nullable) NSString *appVersion;
@property (nonatomic, copy, nullable) NSString *testedVersion;

/// Whether the two match, once both are known.
- (BOOL)runsTestedVersion;
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

/// Every Albrhi tweak installed, one entry per app it targets.
///
/// Read from each tweak's own filter file, so this reflects what is really on the device
/// rather than what this panel was compiled expecting. A tweak added later needs no change
/// here: install it and it appears.
+ (NSArray<SCIPanelEntry *> *)entries;

/// The version of Albrhi that is actually installed, as the package manager records it.
///
/// **Not this bundle's own version, which is the wrong number to show.** Someone who
/// installed Albrhi 1.0.11 was being told "v0.6.0" — the panel component's number, which
/// nothing on their device or on the source ever named. The combined package is what
/// they chose and what they would quote in a report, so it is what the page says.
///
/// Read from dpkg's status file rather than compiled in: a number baked at build time is
/// right only until the next release forgets to change it, and this one is the record of
/// what is on the phone rather than what a build intended.
///
/// Returns nil when nothing can be read — installed as a raw .dylib, or a status file
/// somewhere this has not been taught to look.
+ (nullable NSString *)installedSuiteVersion;

@end

NS_ASSUME_NONNULL_END
