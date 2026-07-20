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
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_refresh_t") subtitle:SCILocalized(@"p_reels_refresh_s") defaultsKey:@"refresh_reel_confirm"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_autonext_t") subtitle:SCILocalized(@"p_reels_autonext_s") defaultsKey:@"reels_auto_next"]
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
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_noscroll_t") subtitle:SCILocalized(@"p_reels_noscroll_s") defaultsKey:@"disable_scrolling_reels" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_reels_doom_t") subtitle:SCILocalized(@"p_reels_doom_s") defaultsKey:@"prevent_doom_scrolling"],
                    [SCISetting stepperCellWithTitle:SCILocalized(@"p_reels_doomcount_t") subtitle:SCILocalized(@"p_reels_doomcount_s") defaultsKey:@"doom_scrolling_reel_count" min:1 max:100 step:1 label:SCILocalized(@"p_lbl_reels") singularLabel:SCILocalized(@"p_lbl_reel")]
                ]
            }
        ];
    }];
}

@end
