//
//  Upsell.x
//  Albrhi for YouTube Music
//
//  **The advertisement for Premium, hidden. Not the subscription, claimed.**
//
//  Upstream keeps both in one file, and this project refused that file whole in 0.2.0 -- correctly
//  at the time, and too bluntly. Read method by method, `PremiumStatus.x` is two different things:
//  hooks that answer *is this account paying* with YES, and hooks that stop the app **asking you to
//  pay**. The first is taking money from the app's developers. The second is closing an
//  advertisement, and the app behaves exactly as it did before for a free account.
//
//  So the line is drawn per selector rather than per file, and what did not come is named:
//
//    isPremiumSubscriber / setIsPremiumSubscriber:  on five classes -- the claim itself
//    isCurrentUserPremium, isMobileAudioTier…       the same claim wearing other names
//    isInternallyDistributedBuild, isUnitTesting…   pretending to be an internal build
//    hasOnboarded, the downloads pivot-bar tab      not this feature, not carried over
//    YTMWatchViewController -init                   forced `_isMobileAudioTierMode` into a private
//                                                   ivar by KVC: the same claim, written by hand
//
//  What is here refuses upsell dialogs, promo sheets, interstitials, the memento promotions, the
//  side-panel upgrade entry, the offline and background upsell renderers, and the throttle that
//  decides when to show the next one. **Every one of them is the app selling; none of them is the
//  app asking what you have bought.**
//
//  Carried over from YTMEnhanced (github.com/py233/YTMEnhanced) under GPLv3, itself derived from
//  YTMusicUltimate by dayanch96.
//
#import "../YTMShared.h"


@interface YTIPivotBarItemRenderer : NSObject
@property(copy, nonatomic) NSString *pivotIdentifier;
- (NSString *)pivotIdentifier;
@end

@interface YTIPivotBarSupportedRenderers : NSObject
@property(retain, nonatomic) YTIPivotBarItemRenderer *pivotBarItemRenderer;
- (YTIPivotBarItemRenderer *)pivotBarItemRenderer;
@end

@interface YTIPivotBarRenderer : NSObject
- (NSMutableArray <YTIPivotBarSupportedRenderers *> *)itemsArray;
@end

@interface YTMWatchViewController : NSObject
@end

%group YTMUpsell

%hook MDXFeatureFlags
- (BOOL)areMementoPromotionsEnabled {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (void)setAreMementoPromotionsEnabled:(BOOL)enabled {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(NO);
    } else {
        %orig;
    }
}
%end

%hook YTMIntegrationsSettingsViewController
- (void)showUpsellingDialog {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)showPromotionScreen {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMCastSessionControllerImpl
- (void)showAudioCastUpsellDialog {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTAdBaseVideoPlayerOverlayViewController
- (void)playbackRouteButtonWillShowPromotion {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTShareMainViewController
- (void)addPromoViewController {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)sharePanelPromoViewController:(id)arg1 dismissWithDismissalExpiryMs:(long long)arg2 onDismissTitleLink:(id)arg3 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTSurveyPromosheet
- (id)expandablePromosheetDelegate { 
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)setExpandablePromosheetDelegate:(id)arg1 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTColdConfig
- (BOOL)cxClientDisableMementoPromotions { 
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)iosEnableNewPromoForcingSettingsPage { 
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (BOOL)iosEnablePromoSkoverlay { 
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (BOOL)mainAppCoreClientIosHidePromoSheetOnKeyboardShown { 
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (BOOL)queueClientGlobalConfigIosEnableElementRendererPromoInQueue { 
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTInterstitialPromoViewController
- (void)showInterstitialPromo:(id)arg1 interstitialParentResponder:(id)arg2 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (id)interstitialPromoView {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)showInterstitialPromo:(id)arg1 enableClientImpressionThrottling:(BOOL)arg2 interstitialParentResponder:(id)arg3 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTShareMainView
- (BOOL)shouldShowPromo {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (void)setPromoView:(id)arg1 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTSharePanelPromoViewController
- (id)promoView {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
%end

%hook YTPromosheetContainerView
- (void)setPromosheet:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)setPromosheet:(id)arg1 animated:(BOOL)arg2 completion:(id)arg3 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)setPromosheetDisplayed:(BOOL)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTQueueController
- (void)promoteAutoplayItemsAtIndexPaths:(id)arg1 userTriggered:(BOOL)arg2 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTPromoThrottleControllerImpl
- (BOOL)canShowThrottledPromo {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTHintController
- (void)sendPromoEventWithAccept:(BOOL)arg1 sendClick:(BOOL)arg2 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTIPlayabilityStatus
- (id)backgroundUpsell {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (id)offlineUpsell {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
%end

%hook YTIBackgroundabilityRenderer
- (id)backgroundUpsell {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
%end

%hook YTMAppDelegate
- (void)showUpsellAlertWithTitle:(id)arg1 subtitle:(id)arg2 upgradeButtonTitle:(id)arg3 upsellURLString:(id)arg4 sourceApplication:(id)arg5 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMUpsellDialogController
- (void)fillAlertViewWithUpsell:(id)upsell {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)showUpsellDialogWithUpsell:(id)upsell upsellParentResponder:(id)responder {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)showUpsellDialogWithUpsell:(id)upsell videoID:(id)ID toastType:(long long)type upsellParentResponder:(id)reponder shouldDismissOnBackgroundTap:(BOOL)shouldDismissOnBackgroundTap {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)showUpsellDialogWithUpsellResponderEvent:(id)responderevent {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook MDXPromotionManager
- (void)presentMementoPromotionIfTriggerConditionsAreSatisfied {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)presentMementoPromotion:(long long)arg1 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTPlayerPromoController
- (void)showBackgroundabilityUpsell {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)showBackgroundOnboardingHint {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)showPipOnboardingHint {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMMusicAppMetadata
- (id)sidePanelPromo{
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (id)unlimitedSettingsButton {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
%end

%hook YTMXSDKContentController
- (BOOL)shouldDisplayUpsell {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (void)parseUpsellPromotionInfos:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial{
    return YTMU(@"YTMUltimateIsEnabled") ? YES : %orig;
}
- (void)setShouldThrottleInterstitial:(BOOL)throttle {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        %orig(YES);
    } else {
        %orig;
    }
}
%end

%hook YTMAppResponder
- (void)presentInterstitialPromoForEvent:(id)event{
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)presentFullscreenPromoForEvent:(id)event{
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)presentInterstitialGridPromoForEvent:(id)event{
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTPromosheetController
- (void)presentPromosheetWithEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (BOOL)canPresentPromosheetWithGlobalThrottling:(BOOL)arg1 customizedThrottling:(id)arg2 shouldReplacePromosheet:(BOOL)arg3 {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTOfflineButtonPromoController
- (void)showOfflinePromoWithRenderer:(id)arg1 endpoint:(id)arg2 parentResponder:(id)arg3 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTUserDefaults
- (BOOL)isPromoForced {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTMMusicAppMetadataImpl
- (id)sidePanelPromo {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
%end

%hook YTMAppResponderImpl
- (void)setUpsellDialogController:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (id)upsellDialogController { 
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)presentFullscreenPromoForEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)presentInterstitialGridPromoForEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)presentInterstitialPromoForEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)setOfflineButtonPromoController:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (id)offlineButtonPromoController {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)executeCommandWrapperPromoRenderer:(id)arg1 firstResponder:(id)arg2 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (BOOL)shouldMealbarPromoController:(id)arg1 displayConnectionStatusMealbar:(id)arg2 hasContentDownloaded:(BOOL)arg3 {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTColdConfig
- (BOOL)enableYouthereCommandsOnIos {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (void)showYouTherePrompt {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt {
    return YTMU(@"YTMUltimateIsEnabled") ? NO : %orig;
}
- (void)showYouTherePrompt {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMAppMealbarPromoController
- (id)mealbarPromoController {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
- (void)setMealbarPromoController:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (void)setMealbarPromoRendererButtonColors:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMNavigationImpl
- (void)presentPromosheetWithEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
- (id)mealbarPromoController {
    return YTMU(@"YTMUltimateIsEnabled") ? nil : %orig;
}
%end

%hook YTMInterstitialPromoViewControllerImpl
- (void)showInterstitialPromo:(id)arg1 interstitialParentResponder:(id)arg2 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMConnectivityMealbarControllerImpl
- (void)showMealbarPromoRenderer:(id)arg1 hasContentDownloaded:(BOOL)arg2 {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMContentViewController
- (void)presentPromosheetWithEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%hook YTMealbarPromoController
- (void)showMealbarPromoWithEvent:(id)arg {
    if (!YTMU(@"YTMUltimateIsEnabled")) {
        %orig;
    }
}
%end

%end

void SCIYTMInstallUpsell(void) { %init(YTMUpsell); }
