#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The recording-quality fix. This is the whole first feature.
///
/// ## The problem, exactly
///
/// CarPlay audio is playing over a car's speakers -- high quality, over A2DP, the
/// Bluetooth profile built for music. Camera opens and starts recording, and the
/// moment it does, `AVCaptureSession` asks for a `PlayAndRecord` audio session so the
/// video can carry sound. The category Camera asks for does not include
/// `AVAudioSessionCategoryOptionAllowBluetoothA2DP` -- only plain
/// `AllowBluetooth`, which is HFP, the phone-call profile: mono, a fraction of A2DP's
/// sample rate, built for two people talking rather than for music. So the car's own
/// speakers, still playing the same song, suddenly sound like a phone call. Nothing
/// broke; the app just asked for a lower-quality route the instant it needed a
/// microphone, because HFP is the only Bluetooth profile that carries both directions.
///
/// ## The fix, exactly
///
/// Ask for both things separately, because iOS lets you: `AllowBluetoothA2DP` keeps
/// the *output* on the high-quality profile, and `-setPreferredInput:` pointed at the
/// device's own built-in microphone keeps the *input* off Bluetooth entirely. Recording
/// uses the iPhone's mic -- which is what most people actually want anyway, since a
/// car's cabin mic (where one exists) usually is not aimed at whatever the camera is
/// pointed at -- while the car's speakers never leave A2DP. Both calls are public,
/// documented `AVAudioSession` API; nothing here is a private framework or a guess
/// about undocumented behavior.
///
/// ## What this deliberately does not attempt
///
/// It does not try to keep the *microphone* on Bluetooth while forcing the output to
/// stay on A2DP -- iOS ties Bluetooth input and output to the same profile as a
/// platform rule, not an app choice, and no app-level API changes that. If the car
/// microphone is genuinely wanted, HFP is what carries it, and this policy has an
/// "Automatic" mode that leaves iOS to its own default for exactly that case.
///
@interface SCICPAudioPolicy : NSObject

/// Called when a recording session is about to start. Saves whatever the session was
/// already configured as, then applies the preferred-mic policy.
+ (void)applyForRecording;

/// Called when the recording session stops. Puts the category, mode and options back
/// the way they were found -- not a hardcoded default, because whatever was there
/// before belonged to something else that may still be running.
+ (void)restorePrevious;

@end

NS_ASSUME_NONNULL_END
