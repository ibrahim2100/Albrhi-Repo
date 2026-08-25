//
//  PlaybackRate.x
//  Albrhi for YouTube Music
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived
//  from YTMusicUltimate. Kept diffable against upstream: the edits are the %group wrapper and
//  its installer, the shared YTMU() reader, and any one-line %orig body opened out because
//  the Logos this repository pins needs %orig alone in a full block.
//
#import "../YTMShared.h"


static BOOL playbackRateButton(void) {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"playbackRateButton");
}

%group YTMPlaybackRate

%hook YTMModularNowPlayingViewController
- (BOOL)playbackRateButtonEnabled {
    return playbackRateButton() ? YES : %orig;
}

- (void)setPlaybackRateButtonEnabled:(BOOL)enabled {
    if (playbackRateButton()) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMPlayerControlsView
- (BOOL)playbackRateButtonEnabled {
    return playbackRateButton() ? YES : %orig;
}

- (void)setPlaybackRateButtonEnabled:(BOOL)enabled {
    if (playbackRateButton()) {
        %orig(YES);
    } else {
        %orig;
    }
}

// Thanks to @danpashin for help
- (void)setupPlaybackRateButtons {
    %orig;

    NSMutableArray *buttonsConstraints = [NSMutableArray arrayWithCapacity:self.playbackRateButtons.count * 2];

    for (YTMPlaybackRateButtonHolder *holder in self.playbackRateButtons) {
        holder.button.translatesAutoresizingMaskIntoConstraints = NO;
        [buttonsConstraints addObject:[holder.button.leadingAnchor constraintEqualToAnchor:self.leadingAnchor]];
        [buttonsConstraints addObject:[holder.button.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]];
    }

    [NSLayoutConstraint activateConstraints:buttonsConstraints];
}
%end

%end

void SCIYTMInstallPlaybackRate(void) { %init(YTMPlaybackRate); }
