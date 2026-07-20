#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Auto-advance to the next reel.
///
/// Instagram already has an auto-scroll system on IGSundialFeedViewController; when
/// `reels_auto_next` is on, force its state getters to YES so a finished reel scrolls
/// to the next on its own. Toggled from Reels settings — no on-screen button, so the
/// reels action bar (and its download button) stay exactly as Instagram lays them out.
///

%hook IGSundialFeedViewController

- (BOOL)autoAdvanceToNextItem {
    if ([SCIUtils getBoolPref:@"reels_auto_next"]) return YES;
    return %orig;
}

- (BOOL)autoScrollState {
    if ([SCIUtils getBoolPref:@"reels_auto_next"]) return YES;
    return %orig;
}

%end
