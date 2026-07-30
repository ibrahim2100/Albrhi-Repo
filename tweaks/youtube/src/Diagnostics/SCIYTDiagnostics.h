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

/// The whole report as text, exactly as the page shows it and the copy button copies.
+ (NSString *)report;

+ (UIViewController *)viewController;

@end
