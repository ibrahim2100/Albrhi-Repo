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

/// The last thing SponsorBlock did, in one line.
///
/// Added because 0.3.0 shipped unable to read a video ID and there was no way to see
/// that from the phone: the feature simply never fired, which looks identical to "no
/// segments exist for this video" and to "the hook did not attach". Three different
/// faults with one symptom is exactly what this page exists to separate.
+ (void)recordSponsorState:(NSString *)state;

/// Which progress-bar class the markers were drawn on, and how many.
///
/// Separate from the state above because they answer different questions: that one says
/// whether segments were found, this one says whether the bar was. Three bar classes are
/// hooked and only one of them exists in any given build -- this reports which.
+ (void)recordMarkerBar:(NSString *)className count:(NSInteger)count;

/// The whole report as text, exactly as the page shows it and the copy button copies.
+ (NSString *)report;

/// YouTube's own version, for the identity card and the report.
+ (NSString *)appVersion;

/// Whether every class the features hook is actually present.
///
/// Read by the identity card so the answer is the first thing on the settings screen
/// rather than something to go looking for. Earlier versions buried it -- 0.1.0 put it
/// behind the very thing that had failed.
+ (BOOL)featuresAttached;

/// Writes the report to a file inside the app's own container, and returns its path.
///
/// 0.1.0 put the only way to read a diagnostic *inside* the settings section, so when
/// that section failed to appear there was no way to find out why -- the one failure
/// the page exists to explain was the one it could not explain. This is the way out
/// that does not depend on any hook having worked.
+ (NSString *)writeReportToFile;

+ (UIViewController *)viewController;

@end
