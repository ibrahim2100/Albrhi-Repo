#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The shortcuts under the settings header.
///
/// Albrhi has grown past a hundred switches, and the common cases are not "change
/// one thing" — they are "make it private", "I only want the downloads", "put it
/// back how it was". Each of those meant hunting through five pages. A preset sets
/// the handful of switches that case is about, and says how many it changed.
///
/// A preset never silently changes anything else: switches outside its own list are
/// left exactly as they were, so applying one is not a reset.
///
@interface SCIQuickPresets : NSObject

/// The row of shortcut buttons shown beneath the brand header.
/// @param width  the table's width, since a table header view is laid out by hand
///               rather than autoresized into place.
+ (UIView *)shortcutsViewWithWidth:(CGFloat)width;

/// How tall that row is, so the header can size itself.
+ (CGFloat)shortcutsHeight;

@end

NS_ASSUME_NONNULL_END
