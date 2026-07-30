#import <UIKit/UIKit.h>

///
/// Runtime truth about this build, and about the last video the player was handed.
///
/// Instagram's equivalent page exists because two features were "fixed" repeatedly
/// against classes that were never instantiated. YouTube starts with the same page
/// for a sharper reason: how downloading can work at all depends on which stream
/// path a given build and account actually receives, and that is not readable from
/// the binary. It has to be printed from a real device.
///
@interface SCIYTDiagnostics : NSObject

/// Recorded by the playback hooks, read by the page. Nil until a video plays.
+ (void)recordPlayerResponse:(id)response;
+ (void)recordVideo:(id)video;

/// Recorded by the settings hooks: the groups YouTube's settings screen is built
/// from, with the type of each. Those numbers cannot be read out of the binary, and
/// getting the wrong one is why 0.1.0 showed no section at all.
+ (void)recordSettingsGroups:(NSArray *)groups;

/// Recorded when the panel could not be built. It is caught rather than allowed to
/// reach the app, so it has to be written down somewhere or the failure is invisible.
+ (void)recordPanelFailure:(NSString *)reason;

/// The whole report as text, exactly as the page shows it and the copy button copies.
+ (NSString *)report;

/// Writes the report to a file inside the app's own container, and returns its path.
///
/// 0.1.0 put the only way to read a diagnostic *inside* the settings section, so when
/// that section failed to appear there was no way to find out why -- the one failure
/// the page exists to explain was the one it could not explain. This is the way out
/// that does not depend on any hook having worked.
+ (NSString *)writeReportToFile;

+ (UIViewController *)viewController;

@end
