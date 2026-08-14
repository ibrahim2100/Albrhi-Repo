#import <Foundation/Foundation.h>

/// Hooks AVCaptureSession start/stop to run the recording-audio policy. Safe to call
/// unconditionally; the policy itself is what checks the preference.
void SCICPInstallAudioHooks(void);
