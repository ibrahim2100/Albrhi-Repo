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

/// Whether a string is one of Instagram's own timestamps ("2h", "1 hour ago").
+ (BOOL)isRelativeTimestamp:(nullable NSString *)text;

/// The instant a relative string refers to, or nil if it is not one.
///
/// Instagram writes these itself rather than going through Foundation, so this is
/// the only date available at the point the text is set. It is as precise as the
/// wording: "1 hour ago" pins the hour but not the minute, which the caller
/// should prefer a real model date over whenever it can reach one.
+ (nullable NSDate *)dateFromRelativeText:(nullable NSString *)text;

/// A one-line sample of the current settings, for the settings row subtitle.
+ (NSString *)previewString;

@end

NS_ASSUME_NONNULL_END
