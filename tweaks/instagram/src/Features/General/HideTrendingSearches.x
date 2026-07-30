#import "../../Utils.h"
#import "../../InstagramHeaders.h"

%hook IGDSSegmentedPillBarView
- (void)didMoveToWindow {
    %orig;

    if ([[self delegate] isKindOfClass:%c(IGSearchTypeaheadNavigationHeaderView)]) {
        if ([SCIUtils getBoolPref:@"hide_trending_searches"]) {
            SCILogV(@"[SCInsta] Hiding trending searches");

            [self removeFromSuperview];
        }
    }
}
%end