//
//  AVSwitching.x
//  Albrhi for YouTube Music
//
//  **Audio or video, and the choice between them.**
//
//  YouTube Music decides for itself whether a track plays as audio or as its video, and hides the
//  switch on most of them. These hooks open that switch everywhere and let a default be set --
//  which is the one feature of the upstream port that 0.2.0 and 0.3.0 carried the neighbours of and
//  left behind.
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived from
//  YTMusicUltimate by dayanch96. Kept diffable: the edits are the %group wrapper and its installer,
//  the shared readers, and any one-line %orig body opened out for the Logos this repository pins.
//
#import "../YTMShared.h"


// Remove popup reminder 
%group YTMAVSwitching

%hook YTMPlayerHeaderViewController
- (BOOL)shouldDisplayHintForAudioVideoSwitch {
	return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTIPlayerResponse
- (id)ytm_audioOnlyUpsell {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}

- (BOOL)ytm_isAudioOnlyPlayable {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}

- (BOOL)isAudioOnlyAvailabilityBlocked {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}

- (void)setIsAudioOnlyAvailabilityBlocked:(BOOL)blocked{
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(NO);
    } else {
        %orig;
    }
}

- (void)setYtm_isAudioOnlyPlayable:(BOOL)playable{
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMAudioVideoModeController
- (BOOL)isAudioOnlyBlocked {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}

- (void)setIsAudioOnlyBlocked:(BOOL)blocked {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(NO);
    } else {
        %orig;
    }
}

- (void)setSwitchAvailability:(NSInteger)arg1 {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(1);
    } else {
        %orig;
    }
}
%end

%hook YTMQueueConfig
- (BOOL)isAudioVideoModeSupported {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}

- (void)setIsAudioVideoModeSupported:(BOOL)supported {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}

/*
- (BOOL)noVideoModeEnabled {
    return YES;
}

- (void)setNoVideoModeEnabled:(BOOL)enabled {
    %orig(YES);
}
*/
%end

%hook YTMAudioVideoModeControllerInternalImpl
- (void)setSwitchAvailability:(NSInteger)arg1 {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(1);
    } else {
        %orig;
    }
}
- (NSInteger)switchAvailability {
    return YTMU(@"YTMUltimateIsEnabled") ? 1 : %orig;
}
- (BOOL)isAudioOnlyBlocked {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTVideoQualitySwitchRedesignedController
- (void)setAllowAudioOnlyManualQualitySelection:(BOOL)arg1 {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)allowAudioOnlyManualQualitySelection {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTVideoQualitySwitchOriginalController
- (void)setAllowAudioOnlyManualQualitySelection:(BOOL)arg1 {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)allowAudioOnlyManualQualitySelection {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTDefaultQueueConfig
- (BOOL)isAudioVideoModeSupportedForNonPodcasts {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}

- (BOOL)isAudioVideoModeSupported {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}

- (void)setIsAudioVideoModeSupported:(BOOL)supported {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMSettings
- (BOOL)allowAudioOnlyManualQualitySelection {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTMSettingsImpl
- (BOOL)allowAudioOnlyManualQualitySelection {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTIAudioOnlyPlayabilityRenderer
- (BOOL)audioOnlyPlayability {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}

- (int)audioOnlyAvailability {
    return YTMU(@"YTMUltimateIsEnabled") ? 1 : %orig;
}

- (void)setAudioOnlyPlayability:(BOOL)playability {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}

- (id)infoRenderer {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}

- (BOOL)hasInfoRenderer {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTIAudioOnlyPlayabilityRenderer_AudioOnlyPlayabilityInfoSupportedRenderers
- (id)upsellDialogRenderer {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}

- (void)setUpsellDialogRenderer:(id)renderer {
    if (!YTMU(@"YTMUltimateIsEnabled")) return %orig;
}
%end

%hook YTQueueItem
- (BOOL)supportsAudioVideoSwitching {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}

- (void)setSupportsAudioVideoSwitching:(BOOL)arg1 {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMMusicAppMetadata
- (BOOL)isAudioOnlyButtonVisible {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTMMusicAppMetadataImpl
- (BOOL)isAudioOnlyButtonVisible {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTMQueueConfig
- (BOOL)noVideoModeEnabledForMusic {
	return YTMUInt(@"audioVideoMode") == 0 ? YES : %orig;
}

- (BOOL)noVideoModeEnabledForPodcasts {
	return YTMUInt(@"audioVideoMode") == 0 ? YES : %orig;
}
%end

%hook YTMQueueConfigImpl
- (BOOL)isAudioVideoModeSupportedForNonPodcasts {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}

- (BOOL)noVideoModeEnabledForMusic {
	return YTMUInt(@"audioVideoMode") == 0 ? YES : %orig;
}

- (BOOL)noVideoModeEnabledForPodcasts {
	return YTMUInt(@"audioVideoMode") == 0 ? YES : %orig;
}
%end

%hook YTQueueController
- (BOOL)noVideoModeEnabled:(id)arg1 {
	return YTMUInt(@"audioVideoMode") == 0 ? YES : %orig;
}
- (BOOL)isAudioVideoModeSupportedForVideo:(id)video {
    return YTMU(@"YTMUltimateIsEnabled") ?: %orig;
}
%end

%hook YTColdConfig
- (BOOL)iosEnableHighQualityAudioAppSettingsPremiumUpsell { 
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

// %group AVSwitchForAds
// %hook YTDefaultQueueConfig
// - (BOOL)noVideoModeEnabledForMusic {
// 	return 1;
// }

// - (BOOL)noVideoModeEnabledForPodcasts {
// 	return 1;
// }
// %end

// %hook YTUserDefaults
// - (BOOL)noVideoModeEnabled {
//     return YES;
// }

// - (void)setNoVideoModeEnabled:(BOOL)enabled {
//     %orig(YES);
// }
// %end

// %hook YTIAudioConfig
// - (BOOL)hasPlayAudioOnly {
//     return YES;
// }

// - (BOOL)playAudioOnly {
//     return YES;
// }
// %end

// %hook YTMSettings
// - (BOOL)initialFormatAudioOnly {
//     return YES;
// }

// - (BOOL)noVideoModeEnabled{
//     return YES;
// }

// - (void)setNoVideoModeEnabled:(BOOL)enabled {
//     %orig(YES);
// }
// %end
// %end

%end

void SCIYTMInstallAVSwitching(void) { %init(YTMAVSwitching); }
