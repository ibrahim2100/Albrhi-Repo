#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageFeed : NSObject
@end

@implementation SCIPageFeed

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_feed"); }
                                                 icon:@"rectangle.stack"
                                                order:20
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_storytray_t") subtitle:SCILocalized(@"p_feed_storytray_s") defaultsKey:@"hide_stories_tray"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_entirefeed_t") subtitle:SCILocalized(@"p_feed_entirefeed_s") defaultsKey:@"hide_entire_feed"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggposts_t") subtitle:SCILocalized(@"p_feed_nosuggposts_s") defaultsKey:@"no_suggested_post"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggacct_t") subtitle:SCILocalized(@"p_feed_nosuggacct_s") defaultsKey:@"no_suggested_account"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggreels_t") subtitle:SCILocalized(@"p_feed_nosuggreels_s") defaultsKey:@"no_suggested_reels"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_nosuggthreads_t") subtitle:SCILocalized(@"p_feed_nosuggthreads_s") defaultsKey:@"no_suggested_threads"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_feed_autoplay_t") subtitle:SCILocalized(@"p_feed_autoplay_s") defaultsKey:@"disable_feed_autoplay"]
                ]
            }
        ];
    }];
}

@end
