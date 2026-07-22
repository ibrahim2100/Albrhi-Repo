#import "SCIDateFormat.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

// Preference keys, all registered with defaults in Tweak.x.
static NSString *const kEnabled   = @"date_format_enabled";
static NSString *const kPreset    = @"date_format_preset";     // default|absolute|compact|custom
static NSString *const kPattern   = @"date_format_pattern";
static NSString *const kThreshold = @"date_relative_hours";    // 0 = never keep relative
static NSString *const kCompact   = @"date_compact_relative";
static NSString *const kCombine   = @"date_combine";           // off|absolute_first|relative_first

@implementation SCIDateFormat

+ (BOOL)enabled {
    return [SCIUtils getBoolPref:kEnabled];
}

+ (NSString *)preset {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:kPreset];
    return v.length ? v : @"absolute";
}

+ (NSString *)pattern {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:kPattern];
    return v.length ? v : @"{DD}/{MM}/{YYYY} {HH}:{mm}";
}

// MARK: - Placeholders

// Formatters are expensive to build and are asked for on every cell, so one is
// kept per format string rather than allocated per call.
+ (NSString *)formatted:(NSDate *)date with:(NSString *)format {
    static NSMutableDictionary<NSString *, NSDateFormatter *> *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });

    NSDateFormatter *formatter;
    @synchronized (cache) {
        formatter = cache[format];
        if (!formatter) {
            formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = format;
            formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            cache[format] = formatter;
        }
    }
    return [formatter stringFromDate:date];
}

+ (NSString *)renderPattern:(NSString *)pattern forDate:(NSDate *)date {
    if (!pattern.length || !date) return @"";

    // Longest tokens first: {MMM} must not be eaten by {MM}.
    NSArray<NSArray<NSString *> *> *tokens = @[
        @[@"{YYYY}", @"yyyy"], @[@"{MMMM}", @"MMMM"], @[@"{MMM}", @"MMM"],
        @[@"{DD}", @"dd"],     @[@"{MM}", @"MM"],     @[@"{YY}", @"yy"],
        @[@"{HH}", @"HH"],     @[@"{hh}", @"hh"],     @[@"{mm}", @"mm"],
        @[@"{ss}", @"ss"],     @[@"{A}", @"a"],       @[@"{EEE}", @"EEE"]
    ];

    NSMutableString *out = [pattern mutableCopy];
    for (NSArray<NSString *> *token in tokens) {
        if ([out rangeOfString:token[0]].location == NSNotFound) continue;
        [out replaceOccurrencesOfString:token[0]
                             withString:[self formatted:date with:token[1]]
                                options:0
                                  range:NSMakeRange(0, out.length)];
    }
    return out;
}

// MARK: - Relative

/// "2h" / "5d" when compact, "2 hours ago" / "5 days ago" when not.
+ (NSString *)relativeStringForInterval:(NSTimeInterval)seconds compact:(BOOL)compact {
    if (seconds < 0) seconds = 0;

    struct { NSTimeInterval span; NSString *shortUnit; NSString *singular; NSString *plural; } steps[] = {
        { 60,        @"s", @"date_unit_second", @"date_unit_seconds" },
        { 3600,      @"m", @"date_unit_minute", @"date_unit_minutes" },
        { 86400,     @"h", @"date_unit_hour",   @"date_unit_hours"   },
        { 604800,    @"d", @"date_unit_day",    @"date_unit_days"    },
        { 2629800,   @"w", @"date_unit_week",   @"date_unit_weeks"   },
        { 31557600,  @"mo", @"date_unit_month", @"date_unit_months"  },
        { DBL_MAX,   @"y", @"date_unit_year",   @"date_unit_years"   }
    };

    NSTimeInterval divisor = 1;
    for (int i = 0; i < 7; i++) {
        if (seconds < steps[i].span || i == 6) {
            long long value = (long long)(seconds / divisor);
            if (value < 1) value = 1;

            if (compact) return [NSString stringWithFormat:@"%lld%@", value, steps[i].shortUnit];

            NSString *unit = SCILocalized(value == 1 ? steps[i].singular : steps[i].plural);
            return [NSString stringWithFormat:SCILocalized(@"date_ago_format"), (long)value, unit];
        }
        divisor = steps[i].span;
    }
    return @"";
}

// MARK: - Composition

+ (NSString *)absoluteStringForDate:(NSDate *)date {
    NSString *preset = [self preset];

    if ([preset isEqualToString:@"custom"]) {
        return [self renderPattern:[self pattern] forDate:date];
    }
    if ([preset isEqualToString:@"compact"]) {
        return [self renderPattern:@"{DD}/{MM}/{YY}" forDate:date];
    }
    // "absolute" and anything unrecognised: a readable, unambiguous default.
    return [self renderPattern:@"{MMM} {DD}, {YYYY}" forDate:date];
}

+ (NSString *)stringForDate:(NSDate *)date {
    return [self stringForDate:date original:nil];
}

+ (NSString *)stringForDate:(NSDate *)date original:(NSString *)original {
    if (!date || ![self enabled]) return nil;

    BOOL compact = [SCIUtils getBoolPref:kCompact];
    NSTimeInterval age = -[date timeIntervalSinceNow];
    if (age < 0) age = 0;

    NSInteger thresholdHours = [[NSUserDefaults standardUserDefaults] integerForKey:kThreshold];

    // Rendered here rather than reusing Instagram's text, so the compact/worded
    // choice actually takes effect. The original is only a safety net for a date
    // we somehow cannot describe.
    NSString *relative = [self relativeStringForInterval:age compact:compact];
    if (!relative.length) relative = original ?: @"";

    NSString *absolute = [self absoluteStringForDate:date];

    NSString *combine = [[NSUserDefaults standardUserDefaults] stringForKey:kCombine];
    if (!combine.length) combine = @"off";

    if ([combine isEqualToString:@"absolute_first"]) {
        return [NSString stringWithFormat:@"%@ (%@)", absolute, relative];
    }
    if ([combine isEqualToString:@"relative_first"]) {
        return [NSString stringWithFormat:@"%@ – %@", relative, absolute];
    }

    // Not combining: the threshold decides which single form is shown.
    if (thresholdHours > 0 && age < thresholdHours * 3600.0) return relative;
    return absolute;
}

// MARK: - Preview

+ (NSString *)previewString {
    // A moment ago in absolute terms, two hours old in relative terms — enough to
    // show both halves of a combined format.
    NSDate *sample = [NSDate dateWithTimeIntervalSinceNow:-7200];
    NSString *rendered = [self stringForDate:sample original:nil];
    return rendered.length ? rendered : SCILocalized(@"date_preview_off");
}

@end
