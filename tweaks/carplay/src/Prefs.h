#import <Foundation/Foundation.h>

///
/// Every preference this tweak has, named once.
///
/// String keys spread across feature files is how a typo becomes a feature that
/// silently never turns on: nothing checks that the key a hook reads is the key a
/// future settings screen writes. Here they are constants, so a mistake is a compile
/// error.
///

/// Whether anything in this tweak runs at all. Off makes both hook groups do nothing,
/// which is the state to fall back to if either one misbehaves on a real device before
/// there is a proper per-feature switch.
#define SCIPrefEnabled           @"carplay_enabled"

/// The recording-audio fix. On by default: it is the first thing this project exists to
/// fix, and it is safe on its own -- it only ever changes anything while
/// AVCaptureSession is actually running, and puts the session back the way it found it
/// the moment recording stops.
#define SCIPrefAudioFix          @"audio_fix"

/// Which input the fix prefers once recording starts. A string rather than a bool
/// because "automatic" is a real, distinct third choice, not just "iPhone or not" --
/// see SCICPAudioPolicy.h for what each one does.
#define SCIPrefPreferredMic      @"preferred_mic"

#define SCIPrefVerboseLogging    @"verbose_logging"
