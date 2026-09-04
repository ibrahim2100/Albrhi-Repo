//
//  SCILicenseUI.h
//  Albrhi — shared
//
//  **The licence screen, for a tweak that has no panel to send anybody to.**
//
//  Albrhi Panel's licence page is a `PSListController` living in a preference bundle: it exists
//  only where PreferenceLoader does, which is a jailbreak. A tweak installed on its own — and
//  above all a dylib injected into an IPA on a phone with no jailbreak at all — has no such page,
//  no Settings row, and until now no way to enter a key. That is the gap that let a self-contained
//  build ship with `SCIPanelAllowsThisApp()` answering yes unconditionally: there was nowhere to
//  say no from.
//
//  So this is the same screen written against UIKit alone, presented from inside the app by
//  whichever tweak is running. One file, four tweaks: the alternative was four screens drifting
//  apart, which this project has already paid for with four copies of a responder-chain walk.
//
//  What it does *not* do is duplicate the panel's plans card. Buying is a conversation that
//  belongs where the money is discussed; this screen answers "am I licensed, and how do I enter
//  what I was sent".
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCILicenseUI : NSObject

/// Presents the licence screen over `host`.
///
/// Safe to call with nil — it does nothing rather than crashing a settings row, which is the
/// behaviour every other presentation in this project settled on after a nil host turned out to
/// be a real state during layout.
+ (void)presentFrom:(UIViewController *_Nullable)host;

/// A one-line summary for a settings row's detail text: licensed, in grace, expired, or not
/// enforced at all. The same words the panel uses, so two screens describing one fact do not
/// describe it differently.
+ (NSString *)summary;

@end

NS_ASSUME_NONNULL_END
