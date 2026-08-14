#import "SCICPAudioPolicy.h"
#import "../../SCILog.h"
#import <AVFoundation/AVFoundation.h>

///
/// Where the policy actually gets applied: `AVCaptureSession` starting and stopping.
///
/// This is Apple's own class, stable across iOS versions and already used by every app
/// that records video -- there is nothing private or version-specific about the hook
/// point itself, only about what this project does once it fires.
///
/// A capture session can be started and stopped many times in one recording (autofocus
/// reconfiguration, format changes), so the policy functions are written to be safe to
/// call repeatedly: applying twice in a row without a stop in between just re-saves and
/// re-applies, and restoring with nothing saved is a no-op.
///

%hook AVCaptureSession

- (void)startRunning {
    %orig;
    [SCICPAudioPolicy applyForRecording];
}

- (void)stopRunning {
    %orig;
    [SCICPAudioPolicy restorePrevious];
}

%end

void SCICPInstallAudioHooks(void) {
    %init;
    SCILogV(@"audio: AVCaptureSession hooked");
}
