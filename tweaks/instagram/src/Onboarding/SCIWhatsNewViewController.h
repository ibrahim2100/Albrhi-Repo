#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The welcome / what's-new sheet.
///
/// Presented once per version: a hero glyph, the change list, and one button out.
/// Content comes from SCIWhatsNew — this class only lays it out.
///

@interface SCIWhatsNewViewController : UIViewController

/// Presents over whatever is on screen, if this version hasn't been seen yet.
/// Safe to call unconditionally; it no-ops when the screen isn't due.
+ (void)presentIfNeededFromWindow:(nullable UIWindow *)window;

/// Presents regardless of whether the version has been seen. Used by the
/// "show welcome screen again" button in settings.
+ (void)presentFromWindow:(nullable UIWindow *)window;

@end

NS_ASSUME_NONNULL_END
