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
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_ads_t") subtitle:SCILocalized(@"p_general_ads_s") defaultsKey:@"hide_ads"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_metaai_t") subtitle:SCILocalized(@"p_general_metaai_s") defaultsKey:@"hide_meta_ai"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_copydesc_t") subtitle:SCILocalized(@"p_general_copydesc_s") defaultsKey:@"copy_description"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_norecent_t") subtitle:SCILocalized(@"p_general_norecent_s") defaultsKey:@"no_recent_searches"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_colorpicker_t") subtitle:SCILocalized(@"p_general_colorpicker_s") defaultsKey:@"detailed_color_picker"],
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_notes"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_hidenotes_t") subtitle:SCILocalized(@"p_general_hidenotes_s") defaultsKey:@"hide_notes_tray"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_friendsmap_t") subtitle:SCILocalized(@"p_general_friendsmap_s") defaultsKey:@"hide_friends_map"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_notetheming_t") subtitle:SCILocalized(@"p_general_notetheming_s") defaultsKey:@"enable_notes_customization"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_customnote_t") subtitle:SCILocalized(@"p_general_customnote_s") defaultsKey:@"custom_note_themes"]
                ]
            },
            @{
                @"header": SCILocalized(@"p_hdr_focus"),
                @"rows": @[
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_nosuggusers_t") subtitle:SCILocalized(@"p_general_nosuggusers_s") defaultsKey:@"no_suggested_users"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_nosuggchats_t") subtitle:SCILocalized(@"p_general_nosuggchats_s") defaultsKey:@"no_suggested_chats"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_exploregrid_t") subtitle:SCILocalized(@"p_general_exploregrid_s") defaultsKey:@"hide_explore_grid"],
                    [SCISetting switchCellWithTitle:SCILocalized(@"p_general_trending_t") subtitle:SCILocalized(@"p_general_trending_s") defaultsKey:@"hide_trending_searches"]
                ]
            }
        ];
    }];
}

@end
