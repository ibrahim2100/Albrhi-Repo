#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "SCIDateFormat.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Applies the custom date format wherever Instagram writes a timestamp.
///
/// Diagnostics settled where that is. NSRelativeDateTimeFormatter is never called
/// — Instagram composes "1 hour ago" itself — and the text lands in IGCoreTextView,
/// a CoreText view rather than a UILabel, which is why the first scans missed it.
/// Hooking that one class covers every surface drawing text through it, instead of
/// chasing feed, stories and messages separately.
///
/// The wording alone is imprecise: "1 hour ago" fixes the hour but not the minute,
/// which is no good for someone asking to see seconds. So before falling back to
/// it, the owning cell is asked for the real date it was rendered from.
///

@interface IGCoreTextView : UIView
@property (nonatomic, copy) NSString *text;
@end

/// Walks up from the text view looking for the object the post came from, and
/// asks it for its date. Names are resolved through the runtime rather than
/// assumed, so a rename in a future Instagram build degrades to the fallback
/// instead of breaking.
static NSDate *SCIModelDateNear(UIView *view) {
    static NSArray<NSString *> *dateNames = nil;
    static NSArray<NSString *> *modelNames = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dateNames = @[@"takenAt", @"takenAtDate", @"timestamp", @"date", @"createdAt", @"creationDate"];
        modelNames = @[@"media", @"item", @"post", @"feedItem", @"viewModel", @"model"];
    });

    UIView *cursor = view;

    for (NSInteger level = 0; cursor && level < 6; level++, cursor = cursor.superview) {
        for (NSString *modelName in modelNames) {
            SEL modelSelector = NSSelectorFromString(modelName);
            if (![cursor respondsToSelector:modelSelector]) continue;

            id model = nil;
            @try { model = [cursor performSelector:modelSelector]; } @catch (__unused id e) { continue; }
            if (!model) continue;

            for (NSString *dateName in dateNames) {
                SEL dateSelector = NSSelectorFromString(dateName);
                if (![model respondsToSelector:dateSelector]) continue;

                id value = nil;
                @try { value = [model performSelector:dateSelector]; } @catch (__unused id e) { continue; }

                if ([value isKindOfClass:[NSDate class]]) return value;

                // Instagram stores these as Unix seconds in places.
                if ([value isKindOfClass:[NSNumber class]]) {
                    double seconds = [value doubleValue];
                    if (seconds > 1000000000.0 && seconds < 4000000000.0) {
                        return [NSDate dateWithTimeIntervalSince1970:seconds];
                    }
                }
            }
        }
    }
    return nil;
}

/// The replacement for a timestamp string, or nil to leave it alone.
static NSString *SCIRewrittenTimestamp(NSString *text, UIView *view) {
    if (![SCIDateFormat enabled]) return nil;
    if (![SCIDateFormat isRelativeTimestamp:text]) return nil;

    NSDate *exact = SCIModelDateNear(view);
    NSDate *date = exact ?: [SCIDateFormat dateFromRelativeText:text];
    if (!date) return nil;

    [SCIDiagnostics recordDateRewrite:text exact:(exact != nil)];

    NSString *replacement = [SCIDateFormat stringForDate:date original:text];
    return replacement.length ? replacement : nil;
}

%hook IGCoreTextView

- (void)setText:(NSString *)text {
    NSString *replacement = SCIRewrittenTimestamp(text, self);
    %orig(replacement ?: text);
}

- (void)setAttributedText:(NSAttributedString *)attributed {
    NSString *replacement = SCIRewrittenTimestamp(attributed.string, self);
    if (!replacement) {
        %orig;
        return;
    }

    // Rebuilt with the original attributes so the timestamp keeps Instagram's own
    // font and colour rather than reverting to a system default.
    NSDictionary *attributes = attributed.length
        ? [attributed attributesAtIndex:0 effectiveRange:NULL]
        : nil;

    %orig([[NSAttributedString alloc] initWithString:replacement attributes:attributes]);
}

%end
