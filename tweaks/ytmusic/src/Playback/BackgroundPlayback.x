#import <Foundation/Foundation.h>

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

@interface YTMBackgroundUpsellNotificationController : NSObject
- (void)removePendingBackgroundNotifications;
@end

//
// **Two edits to this file, and both are about who decides.**
//
// The hooks are wrapped in a %group: Logos installs an ungrouped %hook from its own
// constructor, before Albrhi's gate is consulted, so "off" would still mean hooks in the
// process. Every tweak here answers that the same way -- one group, %init-ed after the gate.
//
// And upstream's own %ctor is removed. It seeded five keys to 1 whenever they were missing,
// which turns every feature on at load no matter what anyone decided. Albrhi's switch owns
// that dictionary now, written from Tweak.x once the gate has allowed it.
//
%group YTMBackground

%hook YTMBackgroundUpsellNotificationController
- (id)upsellNotificationTriggerOnBackground {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback") ? nil : %orig;
}
- (void)maybeScheduleBackgroundUpsellNotification {
    %orig;
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback")) [self removePendingBackgroundNotifications];
}
%end

%hook YTPlayerStatus
- (id)initWithExternalPlayback:(_Bool)arg1 backgroundPlayback:(_Bool)arg2 inlinePlaybackActive:(_Bool)arg3 cardboardModeActive:(_Bool)arg4 layout:(int)arg5 userAudioOnlyModeActive:(_Bool)arg6 blackoutActive:(_Bool)arg7 clipID:(id)arg8 accountLinkState:(id)arg9 muted:(_Bool)arg10 pictureInPicture:(_Bool)arg11 {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback")) {
        arg1 = YES; arg2 = YES; arg3 = YES; arg6 = YES; arg7 = YES;
    }

    return %orig(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11);
}
%end

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground{
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback") ? YES : %orig;
}
//
// **A fourth edit, and it is the one this repository already had a rule for.** Upstream writes
// this body as a ternary whose two branches are `%orig(YES)` and `%orig` -- two different
// argument structures in one expression. The Logos in the roothide Theos accepts it; the Logos
// in stock Theos answers `Invalid argument structure in %orig` and fails the build, which is
// how CI found it after every local build had passed: **those builds were all roothide.**
//
// `%orig` must sit alone on its own line inside a full block. Written that way here.
//
- (void)setIsPlayableInBackground:(BOOL)backgroundable {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback")) {
        %orig(YES);
        return;
    }
    %orig;
}
%end

%hook YTPlaybackData
- (BOOL)isPlayableInBackground {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback") ? YES : %orig;
}
%end

%hook YTMMusicAppMetadata
- (BOOL)canPlayBackgroundableContent {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback") ? YES : %orig;
}
%end

%hook YTMMusicAppMetadataImpl
- (BOOL)canPlayBackgroundableContent {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback") ? YES : %orig;
}
%end

%hook YTLocalPlaybackController
- (BOOL)isPlaybackBackgroundable {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"backgroundPlayback") ? YES : %orig;
}
%end

%end

///
/// Placed here because a Logos group and its `%init` are file-scoped: the initialiser a
/// `%group` generates is static, so it cannot be reached from another file. Albrhi Watch
/// solved it the same way -- one exported installer per file, called by the constructor
/// once the gate has allowed it.
///
void SCIYTMInstallBackground(void) {
    %init(YTMBackground);
}
