#import "SCITTDiagnostics.h"
#import "../Tweak.h"
#import "../Localization/SCILocalize.h"

@implementation SCITTDiagnostics

static NSUInteger sciModelsSeen = 0;
static NSUInteger sciModelsDropped = 0;

+ (void)recordModelsSeen:(NSUInteger)seen droppedAsAds:(NSUInteger)dropped {
    sciModelsSeen += seen;
    sciModelsDropped += dropped;
}

+ (NSString *)adFilterState {
    if (!sciModelsSeen) return SCILocalized(@"diag_ads_none");
    return [NSString stringWithFormat:SCILocalized(@"diag_ads_counts"),
            (unsigned long)sciModelsDropped, (unsigned long)sciModelsSeen];
}

/// Which hooks have answered at least once, in the order they first did. A set rather
/// than a running tally: TikTok's own checks run continuously in the background, and a
/// number that climbs into the thousands says nothing a single "yes, this ran" does not
/// already say better.
static NSMutableOrderedSet<NSString *> *sciBypassAnswered = nil;

+ (void)recordBypassAnswer:(NSString *)which {
    if (!which.length) return;
    if (!sciBypassAnswered) sciBypassAnswered = [NSMutableOrderedSet orderedSet];
    [sciBypassAnswered addObject:which];
}

+ (NSString *)bypassState {
    if (!sciBypassAnswered.count) return SCILocalized(@"diag_bypass_none");
    return [[sciBypassAnswered array] componentsJoinedByString:@", "];
}

+ (NSString *)report {
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"Albrhi for TikTok %@\n", SCIVersionString];
    [out appendFormat:@"app %@\n\n",
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];

    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_ads"), [self adFilterState]];
    [out appendFormat:@"%@\n  %@\n\n", SCILocalized(@"diag_bypass"), [self bypassState]];

    return out;
}

@end
