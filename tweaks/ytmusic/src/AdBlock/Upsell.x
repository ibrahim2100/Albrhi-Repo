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
#import "../Localization/SCILocalize.h"
#import "../Download/SCIYTMDownloadsController.h"
#import "../Utils/NSBundle+YTMU.h"
#import <objc/runtime.h>

/// The browse id this tweak's own tab answers to. One constant, because a pivot identifier, a
/// target id, a browse id and the check that routes them are four places one string has to match.
static NSString *const kSCIYTMDownloadsPivot = @"FEalbrhi_downloads";

/// The icon type our own tab asks to be drawn with. High enough that the app has no meaning for it,
/// so the hook that draws it cannot be confused with a real one.
static const int kSCIYTMDownloadsIconType = 9931;

/// Logos leaves a hooked class a forward declaration, and this one is asked for its `view` and its
/// child controllers -- all three of which need a complete type. check.py has a rule for exactly
/// this, and it caught this file before the compiler did.
@interface YTMBrowseViewController : UIViewController
@end
#import "../Headers/YTIPivotBarRenderer.h"
#import "../Headers/YTIPivotBarSupportedRenderers.h"


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

//
// **The Upgrade tab itself, and the reason it was missing until 0.6.1.**
//
// This hook was dropped from the extraction on the strength of its *class name*: `YTPivotBarView`
// is also what the downloads feature hooks, in a different file, for a different purpose -- and
// that file was not carried over, so the class was excluded wholesale. **The same class serving two
// features is not two copies of one feature**, and judging by name rather than by what the method
// does is precisely the mistake this project keeps a rule about.
//
// It removes one item from the tab bar's own renderer list: the one whose pivot identifier is
// `SPunlimited`, which is the Upgrade tab. Nothing else in the list is touched, and `%orig` runs
// with the shortened array so the app builds its bar from what is left.
//
%hook YTPivotBarView

- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    if (YTMU(@"YTMUltimateIsEnabled")) {
        NSMutableArray<YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

        NSUInteger index = [items indexOfObjectPassingTest:
            ^BOOL(YTIPivotBarSupportedRenderers *entry, NSUInteger idx, BOOL *stop) {
                return [[[entry pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"SPunlimited"];
            }];

        if (index != NSNotFound) {
            //
            // **Replaced in place rather than removed, which is the whole point of the slot.**
            //
            // Taking the Upgrade tab out leaves four tabs and a gap where a fifth used to be.
            // Building a new item and putting it at the same index keeps the bar the shape the
            // app laid out for, and turns an advertisement into the one screen this tweak has
            // that the app has no equivalent of.
            //
            YTIPivotBarItemRenderer *item = [[NSClassFromString(@"YTIPivotBarItemRenderer") alloc] init];
            item.pivotIdentifier = kSCIYTMDownloadsPivot;
            item.targetId = kSCIYTMDownloadsPivot;

            //
            // **A type nobody else uses, so the drawing hook below can recognise it.**
            //
            // 0.8.0 asked for type 1 and got whatever the app draws for 1 -- which on this build is
            // nothing, so the tab arrived without a glyph. The type is only a number the style
            // object is asked to render; the picture comes from the hook underneath, and it needs
            // a number it can tell apart from the app's own.
            //
            YTIIcon *icon = [[NSClassFromString(@"YTIIcon") alloc] init];
            icon.iconType = kSCIYTMDownloadsIconType;
            item.icon = icon;

            item.title = [NSClassFromString(@"YTIFormattedString")
                formattedStringWithString:SCILocalized(@"downloads_title")];

            YTIBrowseEndpoint *browse = [[NSClassFromString(@"YTIBrowseEndpoint") alloc] init];
            browse.browseId = kSCIYTMDownloadsPivot;

            YTICommand *command = [[NSClassFromString(@"YTICommand") alloc] init];
            command.browseEndpoint = browse;
            item.navigationEndpoint = command;

            YTIAccessibilityData *label = [[NSClassFromString(@"YTIAccessibilityData") alloc] init];
            label.label = SCILocalized(@"downloads_title");

            YTIAccessibilitySupportedDatas *accessibility =
                [[NSClassFromString(@"YTIAccessibilitySupportedDatas") alloc] init];
            accessibility.accessibilityData = label;
            item.accessibility = accessibility;

            YTIPivotBarSupportedRenderers *slot =
                [[NSClassFromString(@"YTIPivotBarSupportedRenderers") alloc] init];
            slot.pivotBarItemRenderer = item;

            // Every class above is asked for by name and any of them being absent means the item
            // cannot be built -- in which case the Upgrade tab is removed and nothing takes its
            // place, which is exactly 0.6.1's behaviour and is a working screen either way.
            if (item && icon && browse && command && slot.pivotBarItemRenderer) {
                [items replaceObjectAtIndex:index withObject:slot];
            } else {
                [items removeObjectAtIndex:index];
            }
        }
    }

    %orig;
}

%end

//
// **The glyph itself, drawn from the bundle this package already ships.**
//
// `YTMusicUltimate.bundle` carries `icons/downloads` and its selected variant at every scale --
// they came with the resources when the lyrics module was carried over, and they are the app's own
// visual language rather than an SF Symbol that would sit differently from its four neighbours.
//
%hook YTMPivotBarItemStyle

- (UIImage *)pivotBarItemIconImageWithIconType:(int)type
                                         color:(UIColor *)color
                                   useNewIcons:(BOOL)isNew
                                      selected:(BOOL)isSelected {
    if (type != kSCIYTMDownloadsIconType) return %orig;

    Class loaderClass = NSClassFromString(@"YTAssetLoader");
    NSBundle *bundle = NSBundle.ytmu_defaultBundle;
    if (!loaderClass || !bundle) return %orig;

    YTAssetLoader *loader = [[loaderClass alloc] initWithBundle:bundle];
    UIImage *image = [loader imageNamed:isSelected ? @"icons/downloads_selected" : @"icons/downloads"];

    // A missing image means the app draws whatever it would have drawn, which is a blank tab rather
    // than a crash -- and the tab still works.
    return image ?: %orig;
}

%end

//
// **And the screen behind it.**
//
// The app routes a tab by its browse id, so the controller it builds for ours is empty -- ours is
// added as a child of it instead. Upstream does the same thing for its own tab, and the shape is
// the one that survives: the app owns the navigation, we own one view inside it.
//
%hook YTMBrowseViewController

- (void)viewDidLoad {
    %orig;

    if (!YTMU(@"YTMUltimateIsEnabled")) return;

    // Two ivar names across builds, both asked for before either is read -- `-valueForKey:` on a
    // name a build does not have runs the app's own code on the way to failing.
    id endpoint = nil;
    if (class_getInstanceVariable([self class], "_navEndpoint") != NULL) {
        endpoint = [self valueForKey:@"_navEndpoint"];
    } else if (class_getInstanceVariable([self class], "_navigationEndpoint") != NULL) {
        endpoint = [self valueForKey:@"_navigationEndpoint"];
    }

    if (!endpoint) return;

    YTIBrowseEndpoint *browse = [endpoint browseEndpoint];
    if (![[browse browseId] isEqualToString:kSCIYTMDownloadsPivot]) return;

    SCIYTMDownloadsController *downloads = [[SCIYTMDownloadsController alloc] init];

    [self addChildViewController:downloads];
    downloads.view.frame = self.view.bounds;
    downloads.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:downloads.view];
    [downloads didMoveToParentViewController:self];
}

%end

%end

void SCIYTMInstallUpsell(void) { %init(YTMUpsell); }
