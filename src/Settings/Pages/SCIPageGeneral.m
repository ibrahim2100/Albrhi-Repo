#import "../SCISettingsRegistry.h"
#import "../TweakSettings.h"

@interface SCIPageGeneral : NSObject
@end

@implementation SCIPageGeneral

+ (void)load {
    [SCISettingsRegistry registerFeaturePageWithTitle:^NSString *{ return SCILocalized(@"page_general"); }
                                                 icon:@"gear"
                                                order:10
                                             sections:^NSArray *{
        return @[
            @{
                @"header": @"",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Hide ads" subtitle:@"Removes all ads from the Instagram app" defaultsKey:@"hide_ads"],
                    [SCISetting switchCellWithTitle:@"Hide Meta AI" subtitle:@"Hides the meta ai buttons/functionality within the app" defaultsKey:@"hide_meta_ai"],
                    [SCISetting switchCellWithTitle:@"Copy description" subtitle:@"Copy description text fields by long-pressing on them" defaultsKey:@"copy_description"],
                    [SCISetting switchCellWithTitle:@"Do not save recent searches" subtitle:@"Search bars will no longer save your recent searches" defaultsKey:@"no_recent_searches"],
                    [SCISetting switchCellWithTitle:@"Use detailed color picker" subtitle:@"Long press on the eyedropper tool in stories to customize the text color more precisely" defaultsKey:@"detailed_color_picker"],
                    [SCISetting switchCellWithTitle:@"Enable liquid glass buttons" subtitle:@"Enables experimental liquid glass buttons within the app" defaultsKey:@"liquid_glass_buttons" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Enable liquid glass surfaces" subtitle:@"Enables liquid glass for other elements, such as menus" defaultsKey:@"liquid_glass_surfaces" requiresRestart:YES],
                    [SCISetting switchCellWithTitle:@"Enable teen app icons" subtitle:@"When enabled, hold down on the Instagram logo to change the app icon" defaultsKey:@"teen_app_icons" requiresRestart:YES]
                ]
            },
            @{
                @"header": @"Notes",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"Hide notes tray" subtitle:@"Hides the notes tray in the dm inbox" defaultsKey:@"hide_notes_tray"],
                    [SCISetting switchCellWithTitle:@"Hide friends map" subtitle:@"Hides the friends map icon in the notes tray" defaultsKey:@"hide_friends_map"],
                    [SCISetting switchCellWithTitle:@"Enable note theming" subtitle:@"Enables the ability to use the notes theme picker" defaultsKey:@"enable_notes_customization"],
                    [SCISetting switchCellWithTitle:@"Custom note themes" subtitle:@"Provides an option to set custom emojis and background/text colors" defaultsKey:@"custom_note_themes"]
                ]
            },
            @{
                @"header": @"Focus/distractions",
                @"rows": @[
                    [SCISetting switchCellWithTitle:@"No suggested users" subtitle:@"Hides all suggested users for you to follow, outside your feed" defaultsKey:@"no_suggested_users"],
                    [SCISetting switchCellWithTitle:@"No suggested chats" subtitle:@"Hides the suggested broadcast channels in direct messages" defaultsKey:@"no_suggested_chats"],
                    [SCISetting switchCellWithTitle:@"Hide explore posts grid" subtitle:@"Hides the grid of suggested posts on the explore/search tab" defaultsKey:@"hide_explore_grid"],
                    [SCISetting switchCellWithTitle:@"Hide trending searches" subtitle:@"Hides the trending searches under the explore search bar" defaultsKey:@"hide_trending_searches"]
                ]
            }
        ];
    }];
}

@end
