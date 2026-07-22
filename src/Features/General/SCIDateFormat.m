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

// MARK: - Reading Instagram's own wording

/// Number + unit, in either the compact form ("2h", "5 d") or the worded one
/// ("1 hour ago", "5 days ago"). Anchored so a caption mentioning "3 minutes of
/// footage" is not mistaken for a timestamp.
+ (NSRegularExpression *)relativeExpression {
    static NSRegularExpression *expression = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        expression = [NSRegularExpression regularExpressionWithPattern:
                      @"^\\s*(\\d+)\\s*"
                      @"(seconds?|minutes?|hours?|days?|weeks?|months?|years?|s|m|h|d|w|mo|y)"
                      @"\\s*(ago)?\\s*$"
                                                               options:NSRegularExpressionCaseInsensitive
                                                                 error:nil];
    });
    return expression;
}

+ (BOOL)isRelativeTimestamp:(NSString *)text {
    if (text.length == 0 || text.length > 24) return NO;
    return [[self relativeExpression] firstMatchInString:text
                                                 options:0
                                                   range:NSMakeRange(0, text.length)] != nil;
}

/// The worded forms that carry no number at all. "Active yesterday" is the one
/// that mattered: it passed the filter as a presence line, then produced nothing,
/// because every other form here is a digit followed by a unit.
///
/// Each maps to a representative instant rather than a precise one — the model's
/// own date is always preferred, and this only runs when there isn't one.
+ (NSDate *)dateFromWordedText:(NSString *)text {
    NSString *lower = text.lowercaseString;

    struct { NSString *word; NSTimeInterval ago; } forms[] = {
        { @"just now",     30 },
        { @"now",          30 },
        { @"today",        3600 * 3 },
        { @"yesterday",    86400 },
        { @"last week",    604800 },
        { @"الآن",          30 },
        { @"اليوم",         3600 * 3 },
        { @"أمس",           86400 },
        { @"امس",           86400 },
    };

    for (size_t i = 0; i < sizeof(forms) / sizeof(forms[0]); i++) {
        if ([lower rangeOfString:forms[i].word].location != NSNotFound) {
            return [NSDate dateWithTimeIntervalSinceNow:-forms[i].ago];
        }
    }
    return nil;
}

/// Converts Arabic-Indic and extended Arabic-Indic digits to ASCII, so "٣" and "۳"
/// parse the same as "3".
+ (NSString *)normalizeDigits:(NSString *)text {
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *ch, NSRange r, NSRange e, BOOL *stop) {
        unichar c = [ch characterAtIndex:0];
        if (c >= 0x0660 && c <= 0x0669)      [out appendFormat:@"%C", (unichar)('0' + (c - 0x0660))];
        else if (c >= 0x06F0 && c <= 0x06F9) [out appendFormat:@"%C", (unichar)('0' + (c - 0x06F0))];
        else [out appendString:ch];
    }];
    return out;
}

/// Within-text (not anchored) number+unit, so "Active 1h ago" and "نشط منذ 3س"
/// still yield a date. Anchored matching is kept for -isRelativeTimestamp, which
/// judges a bare feed timestamp.
+ (NSRegularExpression *)relativeSearchExpression {
    static NSRegularExpression *expression = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        expression = [NSRegularExpression regularExpressionWithPattern:
                      @"(\\d+)\\s*"
                      @"(seconds?|minutes?|hours?|days?|weeks?|months?|years?|mo|[smhdwy])\\b"
                                                               options:NSRegularExpressionCaseInsensitive
                                                                 error:nil];
    });
    return expression;
}

/// Arabic relative wording: "منذ ساعة", "منذ ساعتين", "منذ 3 ساعات", "قبل دقيقة"…
/// Dual forms (ساعتين) mean two; a bare singular means one; a digit overrides.
+ (NSDate *)dateFromArabicRelative:(NSString *)text {
    // Dual forms first — each implies a count of two and must be matched before the
    // singular/plural roots they resemble.
    struct { NSString *word; NSTimeInterval seconds; } duals[] = {
        { @"ثانيتين", 1 }, { @"دقيقتين", 60 }, { @"ساعتين", 3600 },
        { @"يومين", 86400 }, { @"أسبوعين", 604800 }, { @"اسبوعين", 604800 },
        { @"شهرين", 2629800 }, { @"سنتين", 31557600 }, { @"عامين", 31557600 },
    };
    for (size_t i = 0; i < sizeof(duals) / sizeof(duals[0]); i++) {
        if ([text rangeOfString:duals[i].word].location != NSNotFound) {
            return [NSDate dateWithTimeIntervalSinceNow:-(2 * duals[i].seconds)];
        }
    }

    // Singular/plural roots. The count is any digit present, else one.
    struct { NSString *word; NSTimeInterval seconds; } units[] = {
        { @"ثاني", 1 }, { @"دقيق", 60 }, { @"دقائق", 60 },
        { @"ساع", 3600 }, { @"يوم", 86400 }, { @"أيام", 86400 }, { @"ايام", 86400 },
        { @"أسبوع", 604800 }, { @"اسبوع", 604800 }, { @"أسابيع", 604800 }, { @"اسابيع", 604800 },
        { @"شهر", 2629800 }, { @"أشهر", 2629800 }, { @"اشهر", 2629800 }, { @"شهور", 2629800 },
        { @"سنة", 31557600 }, { @"سنوات", 31557600 }, { @"سنين", 31557600 },
        { @"عام", 31557600 }, { @"أعوام", 31557600 }, { @"اعوام", 31557600 },
    };
    for (size_t i = 0; i < sizeof(units) / sizeof(units[0]); i++) {
        if ([text rangeOfString:units[i].word].location == NSNotFound) continue;

        double value = 1;
        NSRange digits = [text rangeOfString:@"\\d+" options:NSRegularExpressionSearch];
        if (digits.location != NSNotFound) value = [[text substringWithRange:digits] doubleValue];
        if (value < 1) value = 1;

        return [NSDate dateWithTimeIntervalSinceNow:-(value * units[i].seconds)];
    }
    return nil;
}

+ (NSDate *)dateFromRelativeText:(NSString *)text {
    if (text.length == 0 || text.length > 48) return nil;

    NSString *normalized = [self normalizeDigits:text];

    // English number+unit, searched within the string ("Active 1h ago").
    NSTextCheckingResult *match = [[self relativeSearchExpression] firstMatchInString:normalized
                                                                             options:0
                                                                               range:NSMakeRange(0, normalized.length)];
    if (match && match.numberOfRanges >= 3) {
        double value = [[normalized substringWithRange:[match rangeAtIndex:1]] doubleValue];
        NSString *unit = [[normalized substringWithRange:[match rangeAtIndex:2]] lowercaseString];

        // Checked longest-first: "mo" must not be read as "m", nor "months" as "minutes".
        double seconds = 0;
        if ([unit hasPrefix:@"mo"])      seconds = 2629800;
        else if ([unit hasPrefix:@"se"] || [unit isEqualToString:@"s"]) seconds = 1;
        else if ([unit hasPrefix:@"mi"] || [unit isEqualToString:@"m"]) seconds = 60;
        else if ([unit hasPrefix:@"h"])  seconds = 3600;
        else if ([unit hasPrefix:@"d"])  seconds = 86400;
        else if ([unit hasPrefix:@"w"])  seconds = 604800;
        else if ([unit hasPrefix:@"y"])  seconds = 31557600;

        if (seconds > 0) return [NSDate dateWithTimeIntervalSinceNow:-(value * seconds)];
    }

    // Arabic number+unit ("منذ ساعة", "منذ 3 ساعات").
    NSDate *arabic = [self dateFromArabicRelative:normalized];
    if (arabic) return arabic;

    // Worded forms that carry no number ("yesterday", "أمس").
    return [self dateFromWordedText:text];
}

// MARK: - Composition

/// The clock half of a pattern, honouring the 12/24-hour switch. Kept in one
/// place so every preset that shows a time obeys the setting — a toggle that
/// only worked on some of them would be worse than none.
+ (NSString *)clockPatternWithSeconds:(BOOL)seconds {
    if ([SCIUtils getBoolPref:@"date_24_hour"]) {
        return seconds ? @"{HH}:{mm}:{ss}" : @"{HH}:{mm}";
    }
    return seconds ? @"{hh}:{mm}:{ss} {A}" : @"{hh}:{mm} {A}";
}

+ (NSString *)absoluteStringForDate:(NSDate *)date {
    NSString *preset = [self preset];

    if ([preset isEqualToString:@"custom"]) {
        return [self renderPattern:[self pattern] forDate:date];
    }
    if ([preset isEqualToString:@"time"]) {
        // Clock only: no date at all, which is the point of this preset.
        return [self renderPattern:[self clockPatternWithSeconds:YES] forDate:date];
    }
    if ([preset isEqualToString:@"datetime"]) {
        return [self renderPattern:[@"{DD}/{MM}/{YYYY} " stringByAppendingString:
                                    [self clockPatternWithSeconds:NO]]
                           forDate:date];
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
