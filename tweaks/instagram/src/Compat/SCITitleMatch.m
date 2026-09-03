#import "SCITitleMatch.h"
#import "../Localization/SCILocalize.h"

/// Per surface: how many titles were offered, and how many matched.
///
/// A tally rather than a snapshot of the last one, for the reason this project has now
/// written down three times: a status overwritten on every row describes no row.
static NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *SCICounts(void) {
    static NSMutableDictionary *counts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ counts = [NSMutableDictionary dictionary]; });
    return counts;
}

/// Whether Instagram is being shown in English at all.
///
/// Read from the app's own effective localization rather than from the device language: a
/// phone set to Arabic with Instagram falling back to English is a real combination, and it is
/// the one where these comparisons unexpectedly *work*. `preferredLocalizations` is what the
/// bundle actually resolved, which is the question being asked.
static BOOL SCIAppIsEnglish(void) {
    static BOOL english = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *first = [NSBundle mainBundle].preferredLocalizations.firstObject;
        english = [first hasPrefix:@"en"];
    });
    return english;
}

BOOL SCIMatchesEnglishTitle(NSString *title, NSArray<NSString *> *englishTitles, NSString *surface) {
    if (!surface.length) surface = @"?";

    NSMutableArray<NSNumber *> *pair = SCICounts()[surface];
    if (!pair) {
        pair = [NSMutableArray arrayWithArray:@[@0, @0]];
        SCICounts()[surface] = pair;
    }
    pair[0] = @(pair[0].integerValue + 1);

    if (!title.length) return NO;

    for (NSString *candidate in englishTitles) {
        if (![title isEqualToString:candidate]) continue;
        pair[1] = @(pair[1].integerValue + 1);
        return YES;
    }
    return NO;
}

NSArray<NSString *> *SCIEnglishTitleReport(void) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    // The language line first, and unconditionally: it is the single fact that turns every
    // zero below from a mystery into an explanation.
    [lines addObject:SCIAppIsEnglish() ? SCILocalized(@"diag_titles_english")
                                       : SCILocalized(@"diag_titles_translated")];

    for (NSString *surface in [SCICounts().allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray<NSNumber *> *pair = SCICounts()[surface];
        [lines addObject:[NSString stringWithFormat:SCILocalized(@"diag_titles_line"),
                          surface,
                          (long)pair[0].integerValue,
                          (long)pair[1].integerValue]];
    }

    if (lines.count == 1) [lines addObject:SCILocalized(@"diag_titles_none")];
    return lines;
}
