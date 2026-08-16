#import "SCITWReport.h"
#import "Tweak.h"
#import "Prefs.h"
#import "Features/Switches/SCITWSwitches.h"
#import "Features/Switches/SCITWFeatures.h"
#import "Features/Media/SCITWImmersiveButton.h"
#import "Features/Ads/SCITWPromotedFilter.h"
#import "Features/Ads/SCITWSuggestedFilter.h"
#import "Features/Confirm/SCITWRepostConfirm.h"
#import "Features/Media/SCITWAvatarSave.h"
#import "Features/Playback/SCITWPictureInPicture.h"

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

    // The button, before the switches, because it is what gets reported about.
    //
    // A page that describes three hundred feature switches in detail and says nothing at
    // all about whether the download button attached is a page that answers the question
    // nobody asked. This line is the one somebody writing in about a missing button needs
    // to paste, and until now there was nothing to paste.
    [text appendFormat:@"immersive button: %@\n", SCITWImmersiveButtonReport()];
    [text appendFormat:@"promoted-tweet filter: %@\n", SCITWPromotedFilterReport()];
    [text appendFormat:@"suggested-account filter: %@\n", SCITWSuggestedFilterReport()];
    [text appendFormat:@"repost confirm: %@\n", SCITWRepostConfirmReport()];
    [text appendFormat:@"avatar save: %@\n", SCITWAvatarSaveReport()];
    [text appendFormat:@"picture-in-picture: %@\n", SCITWPictureInPictureReport()];
    [text appendFormat:@"in-video button: %@\n", SCITWInVideoButtonReport()];

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
        // Hand-set beats a feature, exactly as the hot path decides it. Written the same
        // way in both places rather than summarised here: a report that disagrees with the
        // code it describes is worse than no report, because it is believed.
        NSNumber *byHand = overrides[record.key];
        NSNumber *byFeature = fromFeatures[record.key];
        NSNumber *effective = byHand ?: byFeature;

        NSString *note = @"";
        if (effective) {
            note = [NSString stringWithFormat:@"  -> %@ (%@)",
                effective.boolValue ? @"on" : @"off",
                byHand ? @"by hand" : @"feature"];
        }

        [text appendFormat:@"%7lu  %@  %@%@\n",
            (unsigned long)record.asked,
            record.appAnswer ? @"on " : @"off",
            record.key,
            note];
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
