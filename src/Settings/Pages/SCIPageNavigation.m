#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageNavigation : NSObject
@end

@implementation SCIPageNavigation

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_navigation"); }
                                                 icon:@"hand.draw.fill"
                                                order:60
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting menuCellWithTitle:SCILocalized(@"p_nav_order_t") subtitle:SCILocalized(@"p_nav_order_s") menu:[SCITweakSettings menus][@"nav_icon_ordering"]],
                    [SCISetting menuCellWithTitle:SCILocalized(@"p_nav_swipe_t") subtitle:SCILocalized(@"p_nav_swipe_s") menu:[SCITweakSettings menus][@"swipe_nav_tabs"]]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_hidetabs"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_feedtab_t") subtitle:SCILocalized(@"p_nav_feedtab_s") defaultsKey:@"hide_feed_tab" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_exploretab_t") subtitle:SCILocalized(@"p_nav_exploretab_s") defaultsKey:@"hide_explore_tab" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_reelstab_t") subtitle:SCILocalized(@"p_nav_reelstab_s") defaultsKey:@"hide_reels_tab" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_nav_createtab_t") subtitle:SCILocalized(@"p_nav_createtab_s") defaultsKey:@"hide_create_tab" requiresRestart:YES]
                ]
            }
        ];
    }];
}

@end
