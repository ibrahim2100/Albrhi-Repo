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
                    [SCISetting menuCellWithTitle:@"Icon order" subtitle:@"The order of the icons on the bottom navigation bar" menu:[SCITweakSettings menus][@"nav_icon_ordering"]],
                    [SCISetting menuCellWithTitle:@"Swipe between tabs" subtitle:@"Lets you swipe to switch between navigation bar tabs" menu:[SCITweakSettings menus][@"swipe_nav_tabs"]]
                ]
            },
            @{
                @"header": @"Hiding tabs",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Hide feed tab" subtitle:@"Hides the feed/home tab on the bottom navigation bar" defaultsKey:@"hide_feed_tab" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Hide explore tab" subtitle:@"Hides the explore/search tab on the bottom navigation bar" defaultsKey:@"hide_explore_tab" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Hide reels tab" subtitle:@"Hides the reels tab on the bottom navigation bar" defaultsKey:@"hide_reels_tab" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Hide create tab" subtitle:@"Hides the create tab on the bottom navigation bar" defaultsKey:@"hide_create_tab" requiresRestart:YES]
                ]
            }
        ];
    }];
}

@end
