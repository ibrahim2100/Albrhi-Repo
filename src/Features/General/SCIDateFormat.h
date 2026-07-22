#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Renders a timestamp the way the user asked for it.
///
/// Instagram shows relative ages ("2h", "5d") and nothing else, which is useless
/// for telling when something was actually posted. This turns a date into a
/// string built from the preferences: a preset or a pattern of placeholders, an
/// optional threshold under which the relative form is kept, a compact or worded
/// relative style, and an option to show both at once.
///
/// Pure logic with no Instagram dependency, so it can be reasoned about and
/// tested on its own — the hooks that feed it dates are a separate concern.
///
@interface SCIDateFormat : NSObject

/// Whether the user has turned custom dates on at all. Hooks should return the
/// original string when this is NO, so the feature costs nothing when unused.
+ (BOOL)enabled;

/// The finished string for @c date, or nil if it cannot be rendered — callers
/// must fall back to Instagram's own text in that case.
+ (nullable NSString *)stringForDate:(nullable NSDate *)date;

/// The finished string given Instagram's own rendering, so a preset that only
/// wants to *combine* can keep the original relative text rather than
/// re-deriving it. @c original may be nil.
+ (nullable NSString *)stringForDate:(nullable NSDate *)date original:(nullable NSString *)original;

/// Renders an arbitrary pattern, exposed so the settings screen can show a live
/// preview of what the user is typing.
+ (NSString *)renderPattern:(NSString *)pattern forDate:(NSDate *)date;

/// A one-line sample of the current settings, for the settings row subtitle.
+ (NSString *)previewString;

@end

NS_ASSUME_NONNULL_END
