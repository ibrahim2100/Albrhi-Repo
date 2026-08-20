#import <Foundation/Foundation.h>

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static BOOL removeAds(void) {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"noAds");
}

//
// **Wrapped in a %group, which is the only edit made to this file.**
//
// Logos installs an ungrouped %hook from its own constructor, before Albrhi's gate is
// consulted -- so "off" would still mean hooks in the process. Every tweak here answers
// that the same way: one group, %init-ed after the gate. The Spotify port learned it the
// expensive way, where three ungrouped hooks crashed the app whatever the switch said.
//
%group YTMAds

%hook YTAdsInnerTubeContextDecorator
- (void)decorateContext:(id)arg1 {
    if (!removeAds()) return %orig;
}
%end

%hook YTDataUtils
- (id)spamSignalsDictionary {
    return removeAds() ? nil : %orig;
}
%end

%hook YTAdShieldUtils
- (id)spamSignalsDictionary {
    return removeAds() ? nil : %orig;
}
- (id)spamSignalsDictionaryWithoutIDFA {
    return removeAds() ? nil : %orig;
}
%end

%hook YTIPlayerResponse
- (BOOL)isMonetized {
    return removeAds() ? NO : %orig;
}
- (id)paidContentOverlayElementRendererOptions {
    return removeAds() ? nil : %orig;
}
- (BOOL)isCuepointAdsEnabled {
    return removeAds() ? NO : %orig;
}
- (id)adIntroRenderer {
    return removeAds() ? nil : %orig;
}
- (BOOL)isDAIEnabledPlayback {
    return removeAds() ? YES : %orig;
}
%end

%end

///
/// Placed here because a Logos group and its `%init` are file-scoped: the initialiser a
/// `%group` generates is static, so it cannot be reached from another file. Albrhi Watch
/// solved it the same way -- one exported installer per file, called by the constructor
/// once the gate has allowed it.
///
void SCIYTMInstallAdBlock(void) {
    %init(YTMAds);
}
