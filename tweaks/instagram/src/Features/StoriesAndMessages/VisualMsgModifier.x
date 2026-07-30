#import "../../Utils.h"

%hook IGDirectVisualMessage
- (NSInteger)viewMode {
    NSInteger mode = %orig;

    // * Modes *
    // 0 - View Once
    // 1 - Replayable

    if ([SCIUtils getBoolPref:@"disable_view_once_limitations"]) {
        if (mode == 0) {
            mode = 1;

            SCILogV(@"[SCInsta] Modifying visual message from read-once to replayable");
        }
    }
    
    return mode;
}
%end