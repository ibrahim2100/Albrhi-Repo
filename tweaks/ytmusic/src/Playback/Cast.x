//
//  Cast.x
//  Albrhi for YouTube Music
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived
//  from YTMusicUltimate. Kept diffable against upstream: the edits are the %group wrapper and
//  its installer, the shared YTMU() reader, and any one-line %orig body opened out because
//  the Logos this repository pins needs %orig alone in a full block.
//
#import "../YTMShared.h"


%group YTMCast

%hook MDXFeatureFlags
- (BOOL)isCastCloudDiscoveryEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsCastCloudDiscoveryEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)isCastToNativeEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsCastToNativeEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)isCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsCastEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook MDXPlaybackRouteButtonController
- (BOOL)isPersistentCastIconEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTColdConfig
- (BOOL)isCastToNativeEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsCastToNativeEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)isPersistentCastIconEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsPersistentCastIconEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)musicEnableSuggestedCastDevices {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setMusicEnableSuggestedCastDevices:(BOOL)suggest {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)musicClientConfigEnableCastButtonOnPlayerHeader {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setMusicClientConfigEnableCastButtonOnPlayerHeader:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)musicClientConfigEnableAudioOnlyCastingForNonMusicAudio {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setMusicClientConfigEnableAudioOnlyCastingForNonMusicAudio:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMCastSessionController
- (id)premiumUpgradeAction {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)showAudioCastUpsellDialog {
    if (!YTMU(@"YTMUltimateIsEnabled")) return %orig;
}
- (BOOL)isFreeTierAudioCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (void)setIsFreeTierAudioCastEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(NO);
    } else {
        %orig;
    }
}
- (void)openMusicPremiumLandingPage {
    if (!YTMU(@"YTMUltimateIsEnabled")) return %orig;
}
%end

%hook YTMAudioCastUpsellDialogController
- (void)showAudioCastUpsellDialogWithUpsellParentResponder:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) return %orig;
}
%end

%hook YTMCastSessionControllerImpl
- (id)premiumUpgradeAction {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)showAudioCastUpsellDialog {
    if (!YTMU(@"YTMUltimateIsEnabled")) return %orig;
}
- (void)openMusicPremiumLandingPage {
    if (!YTMU(@"YTMUltimateIsEnabled")) return %orig;
}
%end

%hook YTMMusicAppMetadata
- (BOOL)isAudioCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsAudioCastEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
- (BOOL)isMATScreenedCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setIsMATScreenedCastEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMMusicAppMetadataImpl
- (BOOL)isAudioCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)isMATScreenedCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTMSettings
- (BOOL)isAudioCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)isGcmEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTMSettingsImpl
- (BOOL)isAudioCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)isGcmEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTGlobalConfig
- (BOOL)isAudioCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)isGcmEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTMQueueConfig
- (BOOL)isMobileAudioTierScreenedCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTMQueueConfigImpl
- (BOOL)isMobileAudioTierScreenedCastEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook GHCCDeviceCapabilities
- (BOOL)audioSupported {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)hasAudioSupported {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)hasVideoSupported {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)videoSupported {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%hook YTHotConfig
- (BOOL)isCastCloudDiscoveryEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
%end

%end

void SCIYTMInstallCast(void) { %init(YTMCast); }
