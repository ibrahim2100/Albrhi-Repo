#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// A floating status banner for the AV1 transcode.
///
/// It sits in its own pass-through window pinned to the top of the screen: the
/// card catches touches, everything around it does not, so the user keeps
/// scrolling reels while a clip transcodes behind it. All methods are safe to
/// call from any thread.
///
@interface SCITranscodeBanner : NSObject

+ (instancetype)shared;

/// Slides the banner in (or reuses the visible one) with a title.
- (void)showWithTitle:(NSString *)title;

/// Updates the secondary line and the bar. A negative @c fraction shows an
/// indeterminate (pulsing) bar; 0…1 fills it.
- (void)setDetail:(NSString *)detail fraction:(float)fraction;

/// Turns the banner green (success) or orange (failure) with a final message,
/// then slides it away.
- (void)finishWithSuccess:(BOOL)success message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
