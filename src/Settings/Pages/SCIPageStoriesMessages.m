#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageStoriesMessages : NSObject
@end

@implementation SCIPageStoriesMessages

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_stories_messages"); }
                                                 icon:@"rectangle.portrait.on.rectangle.portrait.angled"
                                                order:50
                                             sections:^NSArray *{
        return @[
            @{
                @"header": SCILocalized(@"p_hdr_messages"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_keepdel_t") subtitle:SCILocalized(@"p_sm_keepdel_s") defaultsKey:@"keep_deleted_message"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_markseen_t") subtitle:SCILocalized(@"p_sm_markseen_s") defaultsKey:@"remove_lastseen"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_typing_t") subtitle:SCILocalized(@"p_sm_typing_s") defaultsKey:@"disable_typing_status"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_visual"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_replay_t") subtitle:SCILocalized(@"p_sm_replay_s") defaultsKey:@"unlimited_replay"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_viewonce_t") subtitle:SCILocalized(@"p_sm_viewonce_s") defaultsKey:@"disable_view_once_limitations"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_screenshot_t") subtitle:SCILocalized(@"p_sm_screenshot_s") defaultsKey:@"remove_screenshot_alert"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_seen_t") subtitle:SCILocalized(@"p_sm_seen_s") defaultsKey:@"no_seen_receipt"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"story_seen_button_title") subtitle:SCILocalized(@"story_seen_button_sub") defaultsKey:@"story_seen_button"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_sm_instants_t") subtitle:SCILocalized(@"p_sm_instants_s") defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                ]
            }
        ];
    }];
}

@end
