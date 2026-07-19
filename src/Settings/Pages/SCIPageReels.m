#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageReels : NSObject
@end

@implementation SCIPageReels

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_reels"); }
                                                 icon:@"film.stack"
                                                order:30
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting menuCellWithTitle:@"Tap Controls" subtitle:@"Change what happens when you tap on a reel" menu:[SCITweakSettings menus][@"reels_tap_control"]],
                    [SCISetting switchCellWithTitle:@"Always show progress scrubber" subtitle:@"Forces the progress bar to appear on every reel" defaultsKey:@"reels_show_scrubber"],
                    [SCISetting switchCellWithTitle:@"Disable auto-unmuting reels" subtitle:@"Prevents reels from unmuting when the volume/silent button is pressed" defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Confirm reel refresh" subtitle:@"Shows an alert when you trigger a reels refresh" defaultsKey:@"refresh_reel_confirm"]
                ]
            },
            @{
                @"header": @"Hiding",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Hide reels header" subtitle:@"Hides the top navigation bar when watching reels" defaultsKey:@"hide_reels_header"],
                    [SCISetting switchCellWithTitle:@"Hide reels blend button" subtitle:@"Hides the button in DMs to open a reels blend" defaultsKey:@"hide_reels_blend"]
                ]
            },
            @{
                @"header": @"Limits",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Disable scrolling reels" subtitle:@"Prevents reels from being scrolled to the next video" defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Prevent doom scrolling" subtitle:@"Limits the amount of reels available to scroll at any given time, and prevents refreshing" defaultsKey:@"prevent_doom_scrolling"],
                    [SCISetting stepperCellWithTitle:@"Doom scrolling limit" subtitle:@"Only loads %@ %@" defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:@"reels" singularLabel:@"reel"]
                ]
            }
        ];
    }];
}

@end
