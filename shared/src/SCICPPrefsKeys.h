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
