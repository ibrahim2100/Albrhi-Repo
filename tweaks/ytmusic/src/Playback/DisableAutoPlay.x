//
//  DisableAutoPlay.x
//  Albrhi for YouTube Music
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived
//  from YTMusicUltimate. Kept diffable against upstream: the edits are the %group wrapper and
//  its installer, the shared YTMU() reader, and any one-line %orig body opened out because
//  the Logos this repository pins needs %orig alone in a full block.
//
#import "../YTMShared.h"


static BOOL isDisableAutoRadio(void) {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"disableAutoRadio");
}

// To respect users autoplay switch status
%group YTMAutoPlay

%hook YTDefaultQueueConfig
- (BOOL)autoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%hook YTQueueController
- (BOOL)isAutoplaySupported {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%hook YTMQueueConfig
- (BOOL)autoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%hook YTMQueueConfigImpl
- (BOOL)autoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%hook YTMSettings
- (BOOL)autoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%hook YTMSettingsImpl
- (BOOL)autoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
- (void)setAutoplayEnabled:(BOOL)arg { 
    if (isDisableAutoRadio()) {
        %orig(NO);
    } else {
        %orig;
    }
}
%end

%hook YTUserDefaults
- (BOOL)autoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
- (void)setAutoplayEnabled:(BOOL)arg {
    if (isDisableAutoRadio()) {
        %orig(NO);
    } else {
        %orig;
    }
}
%end

%hook YTMPlaybackQueueAutoplayHeaderReusableView
- (BOOL)isAutoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
- (void)setAutoplayEnabled:(BOOL)arg {
    if (isDisableAutoRadio()) {
        %orig(NO);
    } else {
        %orig;
    }
}
%end

%hook YTMQueueCollectionViewController
- (void)setMDXAutoplayEnabled:(BOOL)arg {
    if (isDisableAutoRadio()) {
        %orig(NO);
    } else {
        %orig;
    }
}
%end

%hook MDXBaseScreen
- (BOOL)isAutoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%hook MDXSessionImpl
- (BOOL)isAutoplayEnabled {
    return isDisableAutoRadio() ? NO : %orig;
}
%end

%end

void SCIYTMInstallAutoPlay(void) { %init(YTMAutoPlay); }
