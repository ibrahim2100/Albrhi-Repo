#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"
#import "../../Downloader/Queue/SCIDownloadCenterViewController.h"

@interface SCIPageDownloads : NSObject
@end

@implementation SCIPageDownloads

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"section_downloads"); }
                                                 icon:@"arrow.down.circle.fill"
                                                order:40
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting navigationCellWithTitle:SCILocalized(@"dl_center_title")
                                               subtitle:SCILocalized(@"dl_center_sub")
                                                   icon:[SCISymbol symbolWithName:@"tray.full.fill" color:[SCIUtils SCIColor_Primary] size:20.0]
                                         viewController:[[SCIDownloadCenterViewController alloc] init]]
                ]
            },
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"dl_use_queue_title") subtitle:SCILocalized(@"dl_use_queue_sub") defaultsKey:@"dl_use_queue"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dl_clear_title") subtitle:SCILocalized(@"dl_clear_sub") defaultsKey:@"dl_clear_after_save"],
                    [SCISetting stepperCellWithTitle:SCILocalized(@"dl_max_concurrent_title") subtitle:@"%@ %@" defaultsKey:@"dl_max_concurrent" min:1 max:6 step:1 label:SCILocalized(@"p_lbl_downloads") singularLabel:SCILocalized(@"p_lbl_download")],
                    [SCISetting switchCellWithTitle:SCILocalized(@"inline_download_title") subtitle:SCILocalized(@"inline_download_sub") defaultsKey:@"inline_download_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_feed_posts_title") subtitle:SCILocalized(@"dw_feed_posts_sub") defaultsKey:@"dw_feed_posts"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_reels_title") subtitle:SCILocalized(@"dw_reels_sub") defaultsKey:@"dw_reels"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_story_title") subtitle:SCILocalized(@"dw_story_sub") defaultsKey:@"dw_story"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"save_profile_title") subtitle:SCILocalized(@"save_profile_sub") defaultsKey:@"save_profile"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"copy_account_info_title") subtitle:SCILocalized(@"copy_account_info_sub") defaultsKey:@"copy_account_info"]
                ]
            },
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_max_quality_title") subtitle:SCILocalized(@"dw_max_quality_sub") defaultsKey:@"dw_max_quality"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"show_quality_picker_title") subtitle:SCILocalized(@"show_quality_picker_sub") defaultsKey:@"show_quality_picker"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_save_to_camera_title") subtitle:SCILocalized(@"dw_save_to_camera_sub") defaultsKey:@"dw_save_to_camera"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"custom_album_title") subtitle:SCILocalized(@"custom_album_sub") defaultsKey:@"custom_album"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_reel_audio_title") subtitle:SCILocalized(@"dw_reel_audio_sub") defaultsKey:@"dw_reel_audio"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"dw_silent_video_title") subtitle:SCILocalized(@"dw_silent_video_sub") defaultsKey:@"dw_silent_video"]
                ]
            },
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting stepperCellWithTitle:SCILocalized(@"dw_finger_count_title") subtitle:@"%@ %@" defaultsKey:@"dw_finger_count" min:1 max:5 step:1 label:SCILocalized(@"p_lbl_fingers") singularLabel:SCILocalized(@"p_lbl_finger")],
                    [SCISetting stepperCellWithTitle:SCILocalized(@"dw_finger_duration_title") subtitle:@"%@ %@" defaultsKey:@"dw_finger_duration" min:0 max:10 step:0.25 label:SCILocalized(@"p_lbl_sec") singularLabel:SCILocalized(@"p_lbl_sec")]
                ]
            }
        ];
    }];
}

@end
