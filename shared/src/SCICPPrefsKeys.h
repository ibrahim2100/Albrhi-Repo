#import <Foundation/Foundation.h>

///
/// The keys Albrhi CarPlay's settings live under, named once.
///
/// Two projects read and write these: Albrhi Panel's CarPlay settings page (running
/// inside Settings, writing through SCIPanelReadBool/SCIPanelReadString's domain) and
/// Albrhi CarPlay itself (running inside SpringBoard or Camera, reading them back). A
/// key spelled once here and typed twice at the call sites is a page whose switch
/// silently changes nothing -- the same mistake SCIPanelGate.h's kSCIPanelDomain
/// comment already warns about, for the same reason.
///
/// The domain is com.albrhi.panel -- the one SCIPanelGate already reads cross-sandbox --
/// not a domain of CarPlay's own. Reusing it means CarPlay's settings ride the one
/// cross-sandbox read path this project has actually gotten working, instead of a
/// second copy of that CFPreferences-then-file dance for a domain nobody has tested.
///

/// The master switch. Bundle identifier "com.albrhi.carplay" is not a real installed
/// app -- it is CarPlay's own package id, used as a stand-in identity so the same
/// question ("is CarPlay on?") has one answer regardless of whether SpringBoard or
/// Camera is the one asking. Read with SCIPanelAllowsApp(SCICPBundleIdentifier).
#define SCICPBundleIdentifier      @"com.albrhi.carplay"

/// The recording-audio fix, on by default.
#define SCICPAudioFixKey           @"carplay_audio_fix_enabled"

/// "iphone", "car" or "automatic" -- see SCICPAudioPolicy.h for what each one does.
#define SCICPPreferredMicKey       @"carplay_preferred_mic"

#define SCICPVerboseLoggingKey     @"carplay_verbose_logging"

/// A comma-separated list of bundle identifiers the user has chosen to bridge onto
/// the CarPlay dashboard -- read by both halves of the app-display feature: the
/// SpringBoard-side admission spoof (SCICPAdmissionSpoof.m, tells CarPlay these
/// bundles may reach the dashboard) and the app-side scene bridge
/// (SCICPSceneBridge.m, only rewrites a scene role for a bundle actually on this
/// list). Comma-separated rather than a picker: v0.3.0 has no on-disk code-signing
/// daemon, so it is scoped to iOS 16/17's runtime admission path, which this project
/// has not built a full app-browser UI for yet -- edited through a single-line
/// UIAlertController text field in the panel, the same safe, already-proven
/// UIAlertController this settings page already uses for its confirmations, rather
/// than guessing at a private multi-line text cell class never confirmed to compile
/// against this project's pinned SDK.
#define SCICPBridgedAppsKey        @"carplay_bridged_apps"
