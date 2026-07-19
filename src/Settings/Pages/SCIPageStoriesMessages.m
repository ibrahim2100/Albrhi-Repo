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
                @"header": @"Messages",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Keep deleted messages" subtitle:@"Saves deleted messages in chat conversations" defaultsKey:@"keep_deleted_message"],
                    [SCISetting switchCellWithTitle:@"Manually mark messages as seen" subtitle:@"Adds a button to DM threads, which will mark messages as seen" defaultsKey:@"remove_lastseen"],
                    [SCISetting switchCellWithTitle:@"Disable typing status" subtitle:@"Prevents the typing indicator from being shown to others when you're typing in DMs" defaultsKey:@"disable_typing_status"]
                ]
            },
            @{
                @"header": @"Visual messages & stories",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Unlimited replay of visual messages" subtitle:@"Replays direct visual messages normal/once stories unlimited times (toggle with image check icon)" defaultsKey:@"unlimited_replay"],
                    [SCISetting switchCellWithTitle:@"Disable view-once limitations" subtitle:@"Makes view-once messages behave like normal visual messages (loopable/pauseable)" defaultsKey:@"disable_view_once_limitations"],
                    [SCISetting switchCellWithTitle:@"Disable screenshot detection" subtitle:@"Removes the screenshot-prevention features for visual messages in DMs" defaultsKey:@"remove_screenshot_alert"],
                    [SCISetting switchCellWithTitle:@"Disable story seen receipt" subtitle:@"Hides the notification for others when you view their story" defaultsKey:@"no_seen_receipt"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"story_seen_button_title") subtitle:SCILocalized(@"story_seen_button_sub") defaultsKey:@"story_seen_button"],
                    [SCISetting switchCellWithTitle:@"Disable instants creation" subtitle:@"Hides the functionality to create/send instants" defaultsKey:@"disable_instants_creation" requiresRestart:YES]
                ]
            }
        ];
    }];
}

@end
