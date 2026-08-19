#import "SCIWDiagnostics.h"

///
/// Counters, not snapshots.
///
/// CLAUDE.md's own rule, bought in another tweak: a diagnostic that records the *last* event
/// reports whatever happened most recently, which on a hot path is almost never the event
/// anybody is asking about. Pairing asks its questions in bursts, so a tally is the only reading
/// that survives the burst.
static NSMutableDictionary<NSString *, NSNumber *> *sciwAnswers = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sciwClasses = nil;

static NSInteger sciwLastWatchMajor = 0;
static NSInteger sciwLastHostMajor = 0;

void SCIWRecordClass(NSString *name, BOOL present) {
    if (!name.length) return;
    if (!sciwClasses) sciwClasses = [NSMutableDictionary dictionary];
    sciwClasses[name] = @(present);
}

void SCIWRecordAnswer(NSString *gate) {
    if (!gate.length) return;
    if (!sciwAnswers) sciwAnswers = [NSMutableDictionary dictionary];
    sciwAnswers[gate] = @(sciwAnswers[gate].unsignedIntegerValue + 1);
}

void SCIWRecordWatchVersion(NSInteger major, NSInteger hostMajor) {
    sciwLastWatchMajor = major;
    sciwLastHostMajor = hostMajor;
}

NSString *SCIWClassReport(void) {
    if (!sciwClasses.count) return @"nothing checked yet";

    NSMutableArray<NSString *> *found = [NSMutableArray array];
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    for (NSString *name in [sciwClasses.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [(sciwClasses[name].boolValue ? found : missing) addObject:name];
    }

    // Both halves, always. "Which classes are here" and "which are not" are the same question
    // asked twice, and a report that only lists what was found cannot distinguish a build that
    // lacks a class from a build this tweak never asked about.
    return [NSString stringWithFormat:@"present: %@ | absent: %@",
        found.count ? [found componentsJoinedByString:@", "] : @"none",
        missing.count ? [missing componentsJoinedByString:@", "] : @"none"];
}

NSString *SCIWAnswerReport(void) {
    if (!sciwAnswers.count) return @"nothing asked yet — iOS asks these while pairing";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *gate in [sciwAnswers.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [parts addObject:[NSString stringWithFormat:@"%@ ×%@", gate, sciwAnswers[gate]]];
    }
    return [parts componentsJoinedByString:@", "];
}

NSString *SCIWVersionReport(void) {
    if (sciwLastWatchMajor <= 0) return @"no watch version read yet";

    return [NSString stringWithFormat:@"watch reads as %ld against iOS %ld — %@",
        (long)sciwLastWatchMajor, (long)sciwLastHostMajor,
        sciwLastWatchMajor > sciwLastHostMajor ? @"newer than this phone"
                                               : @"not newer than this phone"];
}
