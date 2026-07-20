#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Localization/SCILocalize.h"

///
/// Auto-advance to the next reel.
///
/// Instagram already has an auto-scroll system on IGSundialFeedViewController; when
/// `reels_auto_next` is on, force its state getters to YES so a finished reel scrolls
/// to the next on its own. A toggle button is added to the reels action bar, above
/// the download button, so it can be flipped without leaving the reel.
///

// Reuse the inline download button's tag so we can sit just above it.
static const NSInteger SCIInlineDownloadButtonTag = 0x5CD10;
static const NSInteger SCIAutoNextButtonTag = 0x5CA07;

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

%hook IGSundialViewerVerticalUFI

- (void)layoutSubviews {
    %orig;
    [self sciAddAutoNextButton];
}

%new - (void)sciAddAutoNextButton {
    UIButton *button = (UIButton *)[self viewWithTag:SCIAutoNextButtonTag];

    BOOL enabled = [SCIUtils getBoolPref:@"reels_auto_next"];

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = SCIAutoNextButtonTag;
        [button addTarget:self action:@selector(sciToggleAutoNext:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
    }

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"infinity" withConfiguration:config] forState:UIControlStateNormal];
    button.tintColor = enabled ? [SCIUtils SCIColor_Primary] : [UIColor whiteColor];

    // Sit just above the inline download button when present, else near the top.
    UIView *download = [self viewWithTag:SCIInlineDownloadButtonTag];
    CGFloat side = 34.0;
    CGFloat gap = 14.0;

    CGRect frame;
    if (download && !CGRectIsEmpty(download.frame)) {
        frame = CGRectMake(CGRectGetMidX(download.frame) - side / 2.0,
                           CGRectGetMinY(download.frame) - side - gap,
                           side, side);
    } else {
        frame = CGRectMake(CGRectGetWidth(self.bounds) / 2.0 - side / 2.0, -side - gap, side, side);
    }

    button.frame = frame;
    button.hidden = NO;
    [self bringSubviewToFront:button];
}

%new - (void)sciToggleAutoNext:(UIButton *)sender {
    BOOL enabled = ![SCIUtils getBoolPref:@"reels_auto_next"];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"reels_auto_next"];

    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    sender.tintColor = enabled ? [SCIUtils SCIColor_Primary] : [UIColor whiteColor];

    [SCIUtils showToastForDuration:2.0
                             title:SCILocalized(enabled ? @"p_reels_autonext_on" : @"p_reels_autonext_off")];
}

%end
