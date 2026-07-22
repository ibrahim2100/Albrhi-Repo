#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "SCIDateFormat.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Applies the custom date format everywhere at once.
///
/// Chasing Instagram's own view classes surface by surface — feed, then stories,
/// then DMs — is endless, and worse, a label reading "5d" has already thrown away
/// the information needed to show a real time. So the interception happens one
/// level lower, at the formatter that produced the text, where the actual NSDate
/// is still in hand.
///
/// Only NSRelativeDateTimeFormatter is rewritten. Its entire purpose is
/// user-facing relative text, so replacing its output is safe. NSDateFormatter is
/// left strictly alone — an app formats dates for network payloads with it too,
/// and rewriting those would break far more than it fixed. It is recorded only,
/// so diagnostics can still show which path this build actually takes.
///

// Cheap enough to run on every call: a counter and a handful of samples, capped.
static void SCINoteFormatter(NSString *formatter, NSString *sample) {
    [SCIDiagnostics recordDateFormatter:formatter sample:sample];
}

%hook NSRelativeDateTimeFormatter

- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)reference {
    NSString *original = %orig;
    SCINoteFormatter(@"NSRelativeDateTimeFormatter", original);

    if (![SCIDateFormat enabled]) return original;

    NSString *replacement = [SCIDateFormat stringForDate:date original:original];
    return replacement.length ? replacement : original;
}

- (NSString *)localizedStringFromTimeInterval:(NSTimeInterval)interval {
    NSString *original = %orig;
    SCINoteFormatter(@"NSRelativeDateTimeFormatter/interval", original);

    if (![SCIDateFormat enabled]) return original;

    // An interval is relative to now, which is enough to recover the instant.
    NSString *replacement = [SCIDateFormat stringForDate:[NSDate dateWithTimeIntervalSinceNow:interval]
                                                original:original];
    return replacement.length ? replacement : original;
}

%end

// Recorded, never rewritten — see the note above.
%hook NSDateFormatter

- (NSString *)stringFromDate:(NSDate *)date {
    NSString *original = %orig;
    SCINoteFormatter(@"NSDateFormatter", original);
    return original;
}

%end

%hook NSDateComponentsFormatter

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSString *original = %orig;
    SCINoteFormatter(@"NSDateComponentsFormatter", original);
    return original;
}

%end
