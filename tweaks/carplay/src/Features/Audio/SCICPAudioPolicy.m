#import "SCICPAudioPolicy.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCICPDiagnostics.h"
#import <AVFoundation/AVFoundation.h>

/// What the session looked like before this policy touched it. Nil category means
/// nothing has been saved -- restoring then is a no-op rather than forcing a category
/// nobody asked for.
static NSString *sciSavedCategory = nil;
static NSString *sciSavedMode = nil;
static AVAudioSessionCategoryOptions sciSavedOptions = 0;

/// A short description of the route actually in effect, for the report. What iOS
/// granted, not what was asked for -- those can differ, and the difference is the
/// whole reason this feature exists.
static NSString *SCICPRouteDescription(void) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSMutableArray<NSString *> *outputs = [NSMutableArray array];
    NSMutableArray<NSString *> *inputs = [NSMutableArray array];

    for (AVAudioSessionPortDescription *port in session.currentRoute.outputs) {
        [outputs addObject:port.portName ?: port.portType];
    }
    for (AVAudioSessionPortDescription *port in session.currentRoute.inputs) {
        [inputs addObject:port.portName ?: port.portType];
    }

    return [NSString stringWithFormat:@"out: %@ · in: %@",
        outputs.count ? [outputs componentsJoinedByString:@", "] : @"none",
        inputs.count ? [inputs componentsJoinedByString:@", "] : @"none"];
}

/// The built-in microphone's own port, found by type rather than by name -- a name is
/// locale- and device-dependent, the type constant is not.
static AVAudioSessionPortDescription *SCICPBuiltInMicPort(void) {
    AVAudioSession *session = [AVAudioSession sharedInstance];

    for (AVAudioSessionPortDescription *port in session.availableInputs) {
        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic]) return port;
    }
    return nil;
}

@implementation SCICPAudioPolicy

+ (void)applyForRecording {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefAudioFix]) return;

    AVAudioSession *session = [AVAudioSession sharedInstance];

    // Saved before anything changes, so stopping can put it back rather than guessing
    // at a default. Category can legitimately be nil before a session is ever
    // configured -- AVAudioSession still answers, just with nothing meaningful yet.
    sciSavedCategory = session.category;
    sciSavedMode = session.mode;
    sciSavedOptions = session.categoryOptions;

    NSString *preference = [[NSUserDefaults standardUserDefaults] stringForKey:SCIPrefPreferredMic] ?: @"iphone";

    if ([preference isEqualToString:@"automatic"]) {
        SCILogV(@"audio: automatic mode -- leaving the session as Camera set it");
        [SCICPDiagnostics record:@"recording started, automatic mode, no change made"];
        return;
    }

    // AllowBluetoothA2DP is the whole fix for the output side: it is what keeps a car's
    // speakers on the high-quality profile instead of the HFP fallback every
    // PlayAndRecord session drops to the moment a microphone is also requested.
    AVAudioSessionCategoryOptions options =
        AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionAllowBluetooth;

    NSError *error = nil;
    BOOL ok = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                               mode:AVAudioSessionModeVideoRecording
                            options:options
                              error:&error];

    if (!ok) {
        SCILogV(@"audio: category request refused -- %@", error.localizedDescription);
        [SCICPDiagnostics record:
            [@"category request refused — " stringByAppendingString:error.localizedDescription ?: @"?"]];
        return;
    }

    // The input side: pointed at the built-in mic explicitly, which is the only way to
    // keep it off whatever Bluetooth device is currently the output route. Left alone
    // for "car", where HFP carrying both directions is the point.
    if ([preference isEqualToString:@"iphone"]) {
        AVAudioSessionPortDescription *builtIn = SCICPBuiltInMicPort();
        if (builtIn) {
            NSError *inputError = nil;
            if (![session setPreferredInput:builtIn error:&inputError]) {
                SCILogV(@"audio: could not prefer the built-in mic -- %@", inputError.localizedDescription);
                [SCICPDiagnostics record:
                    [@"could not select the iPhone microphone — "
                        stringByAppendingString:inputError.localizedDescription ?: @"?"]];
            }
        } else {
            SCILogV(@"audio: no built-in mic in availableInputs — nothing to prefer");
        }
    }

    [session setActive:YES error:&error];

    SCILogV(@"audio: recording started, preference=%@, route now %@",
            preference, SCICPRouteDescription());
    [SCICPDiagnostics record:
        [NSString stringWithFormat:@"recording started (%@) — %@", preference, SCICPRouteDescription()]];
}

+ (void)restorePrevious {
    if (!sciSavedCategory) return;   // nothing was ever saved; nothing to undo

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    BOOL ok = [session setCategory:sciSavedCategory mode:sciSavedMode options:sciSavedOptions error:&error];

    SCILogV(@"audio: recording stopped, restore %@", ok ? @"ok" : error.localizedDescription);
    [SCICPDiagnostics record:[NSString stringWithFormat:@"recording stopped — restored %@",
        ok ? @"previous session" : (error.localizedDescription ?: @"?")]];

    // Handed back to the system rather than kept pinned to the built-in mic, so a call
    // or another app after recording ends is not stuck on our choice.
    [session setPreferredInput:nil error:nil];

    sciSavedCategory = nil;
    sciSavedMode = nil;
    sciSavedOptions = 0;
}

@end
