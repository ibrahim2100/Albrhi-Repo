#import "../../Utils.h"

%hook IGSundialViewerNavigationBarOld
- (void)didMoveToWindow {
    %orig;

    if ([SCIUtils getBoolPref:@"hide_reels_header"]) {
        SCILogV(@"[SCInsta] Hiding reels header");

        [self removeFromSuperview];
    }
}
%end
