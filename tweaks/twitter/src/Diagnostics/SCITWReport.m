#import "SCITWReport.h"
#import "Tweak.h"
#import "Prefs.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Features/Switches/SCITWFeatures.h"

NSString *SCITWReportText(void) {
    NSMutableString *text = [NSMutableString string];

    [text appendFormat:@"Albrhi for X %@\n", SCIVersionString];
    [text appendFormat:@"app %@ (%@)\n",
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
        [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];
    [text appendFormat:@"written %@\n\n", [NSDate date]];

    // The panel switch first, because when it is off everything below is empty and the
    // reason has to be at the top rather than inferred from an absence.
    [text appendFormat:@"panel gate: %@\n", SCIPanelGateReport()];

    NSArray<NSString *> *providers = [SCITWSwitches attachedProviders];
    [text appendFormat:@"providers hooked: %@\n",
        providers.count ? [providers componentsJoinedByString:@", "] : @"NONE"];

    NSArray<SCITWSwitchRecord *> *records = [SCITWSwitches records];
    [text appendFormat:@"switches seen: %lu over %lu questions\n\n",
        (unsigned long)records.count, (unsigned long)[SCITWSwitches totalAsked]];

    // The named features, before the raw keys. A report that lists forty forced keys and
    // does not say they came from one switch reads as somebody having set forty things by
    // hand, and the first question back is always "what did you actually turn on".
    NSMutableArray<NSString *> *on = [NSMutableArray array];
    for (SCITWFeature *feature in [SCITWFeatures all]) {
        if ([SCITWFeatures isOn:feature]) [on addObject:feature.identifier];
    }
    [text appendFormat:@"features on: %@\n\n",
        on.count ? [on componentsJoinedByString:@", "] : @"none"];

    NSDictionary<NSString *, NSNumber *> *overrides = [SCITWSwitches allOverrides];
    NSDictionary<NSString *, NSNumber *> *fromFeatures = [SCITWSwitches featureOverrides];

    // Overridden keys are listed twice on purpose: once here as their own short list, and
    // again in place below. The short list is what someone pastes into a bug report, and
    // hunting for five changed rows in four hundred is how a report arrives without them.
    [text appendFormat:@"changed by the user: %lu\n", (unsigned long)overrides.count];
    for (NSString *key in [[overrides allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        [text appendFormat:@"  %@ = %@\n", key, overrides[key].boolValue ? @"on" : @"off"];
    }

    [text appendString:@"\n--- every switch seen, most asked first ---\n"];
    for (SCITWSwitchRecord *record in records) {
        NSNumber *override = overrides[record.key];

        [text appendFormat:@"%7lu  %@  %@%@\n",
            (unsigned long)record.asked,
            record.appAnswer ? @"on " : @"off",
            record.key,
            override ? (override.boolValue ? @"  -> forced on" : @"  -> forced off") : @""];
    }

    return text;
}

NSString *SCITWWriteReport(void) {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!documents.length) return nil;

    NSString *name = @"AlbrhiTW-report.txt";
    NSString *path = [documents stringByAppendingPathComponent:name];

    NSError *error = nil;
    BOOL wrote = [SCITWReportText() writeToFile:path
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&error];

    return wrote ? name : nil;
}
