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
                    [SCISetting switchCellWithTitle:@"Hide stories tray" subtitle:@"Hides the story tray at the top and within your feed" defaultsKey:@"hide_stories_tray"],
                    [SCISetting switchCellWithTitle:@"Hide entire feed" subtitle:@"Removes all content from your home feed, including posts" defaultsKey:@"hide_entire_feed"],
                    [SCISetting switchCellWithTitle:@"No suggested posts" subtitle:@"Removes suggested posts from your feed" defaultsKey:@"no_suggested_post"],
                    [SCISetting switchCellWithTitle:@"No suggested for you" subtitle:@"Hides suggested accounts for you to follow" defaultsKey:@"no_suggested_account"],
                    [SCISetting switchCellWithTitle:@"No suggested reels" subtitle:@"Hides suggested reels to watch" defaultsKey:@"no_suggested_reels"],
                    [SCISetting switchCellWithTitle:@"No suggested threads posts" subtitle:@"Hides suggested threads posts" defaultsKey:@"no_suggested_threads"],
                    [SCISetting switchCellWithTitle:@"Disable video autoplay" subtitle:@"Prevents videos on your feed from playing automatically" defaultsKey:@"disable_feed_autoplay"]
                ]
            }
        ];
    }];
}

@end
