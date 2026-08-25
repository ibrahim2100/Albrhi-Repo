//
//  NavBar.x
//  Albrhi for YouTube Music
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived
//  from YTMusicUltimate. Kept diffable against upstream: the edits are the %group wrapper and
//  its installer, the shared YTMU() reader, and any one-line %orig body opened out because
//  the Logos this repository pins needs %orig alone in a full block.
//
//  **And the extension: upstream calls this file `.xm`, which is Objective-C++.** Nothing in it is
//  C++, and the cost is real -- the installer below is a C function, and in a `.xm` it is emitted
//  with C++ mangling while `YTMHooks.h` declares it plainly, so every other file looks for a symbol
//  that is not there and the link fails. check.py already carries a rule for the mirror image of
//  this (a C function in a header imported by `.xm` without `extern "C"`); this is the same fact
//  approached from the definition rather than the declaration.
//
#import "../YTMShared.h"


@interface YTMSortFilterButton : UIButton
@end

%group YTMNavBar

%hook QTMButton
- (void)layoutSubviews {
    %orig;
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"hideHistoryButton")) {
        if ([self.accessibilityIdentifier isEqualToString:@"id.navigation.history.button"]) {
            self.hidden = YES;
        }
    }
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"hideCastButton")) {
        if ([self.accessibilityIdentifier isEqualToString:@"id.mdx.playbackroute.button"]) {
            self.hidden = YES;
        }
    }
}
%end

%hook YTMNavigationBarView
- (void)layoutSubviews {
    %orig;

    NSArray *subviews = [self subviews];

    UIView *sortFilterButton = nil;
    for (UIView *subview in subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"YTMSortFilterButton")]) {
            sortFilterButton = subview;
            break;
        }
    }

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"hideFilterButton")) {
        if (sortFilterButton != nil) {
            [sortFilterButton removeFromSuperview];
        }
    }
}
%end

%end

void SCIYTMInstallNavBar(void) { %init(YTMNavBar); }
