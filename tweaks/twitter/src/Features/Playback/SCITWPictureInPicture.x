#import <Foundation/Foundation.h>
#import "SCITWPictureInPicture.h"
#import "SCILog.h"

///
/// A recorder, on the setter rather than the getter.
///
/// `-setNativePictureInPictureBehavior:` is where X decides the value for a specific
/// player configuration, so counting there -- rather than on the getter, which could be
/// asked many times for one decision -- gives one tally per real decision X made. `%orig`
/// runs first and unconditionally: this file changes nothing, on purpose.
///

@interface TAVPlayerViewConfiguration : NSObject
- (void)setNativePictureInPictureBehavior:(long long)behavior;
@end

static BOOL sciPIPClassPresent = NO;
static NSMutableDictionary<NSNumber *, NSNumber *> *sciPIPValueCounts = nil;

%group PIPRecorder

%hook TAVPlayerViewConfiguration

- (void)setNativePictureInPictureBehavior:(long long)behavior {
    %orig;

    NSNumber *key = @(behavior);
    @synchronized (sciPIPValueCounts) {
        sciPIPValueCounts[key] = @(sciPIPValueCounts[key].unsignedIntegerValue + 1);
    }
}

%end

%end


NSString *SCITWPictureInPictureReport(void) {
    if (!sciPIPClassPresent) return @"TAVPlayerViewConfiguration not in this build";

    NSDictionary *counts;
    @synchronized (sciPIPValueCounts) {
        counts = [sciPIPValueCounts copy];
    }
    if (!counts.count) return @"no value set yet -- play a video and check again";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSNumber *value in [counts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [parts addObject:[NSString stringWithFormat:@"%@×%@", value, counts[value]]];
    }
    return [NSString stringWithFormat:@"values seen (value×count): %@",
        [parts componentsJoinedByString:@", "]];
}

void SCITWInstallPictureInPictureRecorder(void) {
    sciPIPValueCounts = [NSMutableDictionary dictionary];

    sciPIPClassPresent = (NSClassFromString(@"TAVPlayerViewConfiguration") != nil);
    if (!sciPIPClassPresent) {
        SCILogV(@"TAVPlayerViewConfiguration not in this build -- no PIP recorder");
        return;
    }

    %init(PIPRecorder);
    SCILogV(@"picture-in-picture value recorder attached");
}
