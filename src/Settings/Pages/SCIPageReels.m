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
                    [SCISetting menuCellWithTitle:SCILocalized(@"p_reels_tap_t") subtitle:SCILocalized(@"p_reels_tap_s") menu:[SCITweakSettings menus][@"reels_tap_control"]],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_scrubber_t") subtitle:SCILocalized(@"p_reels_scrubber_s") defaultsKey:@"reels_show_scrubber"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_unmute_t") subtitle:SCILocalized(@"p_reels_unmute_s") defaultsKey:@"disable_auto_unmuting_reels" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_refresh_t") subtitle:SCILocalized(@"p_reels_refresh_s") defaultsKey:@"refresh_reel_confirm"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_hiding"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_header_t") subtitle:SCILocalized(@"p_reels_header_s") defaultsKey:@"hide_reels_header"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_blend_t") subtitle:SCILocalized(@"p_reels_blend_s") defaultsKey:@"hide_reels_blend"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_limits"),
                @"rows": @[
                ]
            }
        ];
    }];
}

@end
