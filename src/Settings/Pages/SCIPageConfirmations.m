#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageConfirmations : NSObject
@end

@implementation SCIPageConfirmations

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_confirmations"); }
                                                 icon:@"checkmark"
                                                order:70
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Confirm like: Posts/Stories" subtitle:@"Shows an alert when you click the like button on posts or stories to confirm the like" defaultsKey:@"like_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm like: Reels" subtitle:@"Shows an alert when you click the like button on reels to confirm the like" defaultsKey:@"like_confirm_reels"]
                ]
            },
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Confirm follow" subtitle:@"Shows an alert when you click the follow button to confirm the follow" defaultsKey:@"follow_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm repost" subtitle:@"Shows an alert when you click the repost button to confirm before resposting" defaultsKey:@"repost_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm call" subtitle:@"Shows an alert when you click the audio/video call button to confirm before calling" defaultsKey:@"call_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm voice messages" subtitle:@"Shows an alert to confirm before sending a voice message" defaultsKey:@"voice_message_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm follow requests" subtitle:@"Shows an alert when you accept/decline a follow request" defaultsKey:@"follow_request_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm shh mode" subtitle:@"Shows an alert to confirm before toggling disappearing messages" defaultsKey:@"shh_mode_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm posting comment" subtitle:@"Shows an alert when you click the post comment button to confirm" defaultsKey:@"post_comment_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm changing theme" subtitle:@"Shows an alert when you change a chat theme to confirm" defaultsKey:@"change_direct_theme_confirm"],
                    [SCISetting switchCellWithTitle:@"Confirm sticker interaction" subtitle:@"Shows an alert when you click a sticker on someone's story to confirm the action" defaultsKey:@"sticker_interact_confirm"]
                ]
            }
        ];
    }];
}

@end
