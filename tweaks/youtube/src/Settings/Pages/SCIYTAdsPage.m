#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"

@interface SCIYTAdsPage : NSObject
@end

@implementation SCIYTAdsPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:30
                                        title:SCILocalized(@"page_ads")
                                       detail:SCILocalized(@"page_ads_note")
                                       symbol:@"hand.raised.fill"
                                      builder:^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *host) {
        SCISection *ads = [[SCISection alloc] init];
        ads.title = SCILocalized(@"section_ads");
        ads.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_ads")
                       detail:SCILocalized(@"hide_ads_note")
                       symbol:@"hand.raised.fill"
                      prefKey:SCIPrefHideAds],
            [SCIRow switchRow:SCILocalized(@"hide_paid_promotion")
                       detail:SCILocalized(@"hide_paid_promotion_note")
                       symbol:@"megaphone.fill"
                      prefKey:SCIPrefHidePaidPromo],
        ];
        return @[ads];
    }];
}

@end
