#import <UIKit/UIKit.h>
#import "SCITTProgressBar.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// Keep the playback progress bar on screen.
///
/// TikTok fades its own bar out a moment after a video starts and only restores it while a
/// finger is on it, so there is normally no way to see how far through a clip you are, or to
/// tell a six-second loop from a three-minute one before it repeats.
///
/// **The class is `AWEFeedPlayerBottomProgressBar`, confirmed present in TikTok 46.4.0's own
/// binary** -- not taken on trust from NA9, which hooks the same one. Its Logos symbols name
/// `layoutSubviews`, `setAlpha:` and `setHidden:`, and those two setters are the whole
/// technique: the bar is never removed, only faded and hidden, so answering them is enough
/// and nothing has to be drawn or positioned.
///
/// **This answers the question rather than fighting the view** -- the same shape as this
/// project's successful hooks, and the opposite of what cost the download button seven
/// releases. No subview is added, no frame is owned, nothing competes with TikTok's own
/// layout. If a future build renames the class the hook never attaches and the bar behaves
/// exactly as it does without the tweak.
///
/// `%orig` is called in both cases rather than the property being set directly, so TikTok's
/// own state stays consistent and only the value that lands is overridden. Skipping through
/// would leave the app believing it had hidden something the user can still see, which is how
/// a visibility hook turns into a scrubbing bug.
///

@interface AWEFeedPlayerBottomProgressBar : UIView
@end

static BOOL sciAttached = NO;
static NSUInteger sciKeptVisible = 0;

%group ProgressBar

%hook AWEFeedPlayerBottomProgressBar

- (void)setHidden:(BOOL)hidden {
    // Written out rather than as `{ %orig; return; }` on one line: Logos expands %orig with
    // #line directives and it has to sit alone inside a full block, which check.py's rule 4
    // exists to catch.
    if (!SCIPrefEnabled(SCIPrefProgressBar)) {
        %orig;
        return;
    }

    %orig(NO);
    sciKeptVisible++;
}

- (void)setAlpha:(CGFloat)alpha {
    if (!SCIPrefEnabled(SCIPrefProgressBar)) {
        %orig;
        return;
    }

    // Only the fade to nothing is refused. A partial alpha is TikTok animating the bar in or
    // out, and overriding those would make it flicker at full strength through every
    // transition -- worse to look at than the fade this exists to stop.
    %orig(alpha <= 0.01 ? 1.0 : alpha);
}

%end

%end

void SCITTInstallProgressBar(void) {
    if (!NSClassFromString(@"AWEFeedPlayerBottomProgressBar")) {
        SCILogV(@"progress bar: AWEFeedPlayerBottomProgressBar is not in this build");
        return;
    }

    %init(ProgressBar);
    sciAttached = YES;
    SCILogV(@"progress bar: attached");
}

NSString *SCITTProgressBarReport(void) {
    if (!sciAttached) return @"AWEFeedPlayerBottomProgressBar is not in this build";
    if (!SCIPrefEnabled(SCIPrefProgressBar)) return @"attached, switched off";
    return [NSString stringWithFormat:@"attached — %lu kept visible",
            (unsigned long)sciKeptVisible];
}
