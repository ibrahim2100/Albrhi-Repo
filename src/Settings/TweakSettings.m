#import "TweakSettings.h"
#import "SCISettingsRegistry.h"

///
/// Thin composer over SCISettingsRegistry.
///
/// The settings tree is no longer declared here. Each page lives in its own file
/// under `Settings/Pages/` and registers itself in `+load`, so adding or removing
/// a feature never touches this file. See SCISettingsRegistry.h.
///

@implementation SCITweakSettings

// MARK: - Sections

+ (NSArray *)sections {
    return [SCISettingsRegistry composedSections];
}


// MARK: - Title

+ (NSString *)title {
    return SCILocalized(@"settings_title");
}


// MARK: - Menus

///
/// Shared menu definitions, keyed by name. Each "propertyList" is an NSDictionary of:
///
/// `"defaultsKey"`: The key to save the selected value under in NSUserDefaults
///
/// `"value"`: A unique string corresponding to the selected menu item
///
/// `"requiresRestart"`: (optional) Prompts for a restart after selection
///

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

+ (NSDictionary *)menus {
    return @{
        @"albrhi_language": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:SCILocalized(@"language_system")
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"albrhi_language",
                               @"value": @"system",
                               @"requiresRestart": @YES
                           }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                       identifier:nil
                          options:UIMenuOptionsDisplayInline
                         children:@[
                             [UICommand commandWithTitle:SCILocalized(@"language_arabic")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"albrhi_language",
                                                @"value": @"ar",
                                                @"requiresRestart": @YES
                                            }
                             ],
                             [UICommand commandWithTitle:SCILocalized(@"language_english")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"albrhi_language",
                                                @"value": @"en",
                                                @"requiresRestart": @YES
                                            }
                             ]
                         ]
            ]
        ]],

        @"media_press_action": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:SCILocalized(@"p_press_zoom")
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{ @"defaultsKey": @"media_press_action", @"value": @"zoom" }
            ],
            [UICommand commandWithTitle:SCILocalized(@"p_press_off")
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{ @"defaultsKey": @"media_press_action", @"value": @"off" }
            ]
        ]],

        @"reels_tap_control": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:SCILocalized(@"p_menu_default")
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"reels_tap_control",
                               @"value": @"default",
                               @"requiresRestart": @YES
                           }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                       identifier:nil
                          options:UIMenuOptionsDisplayInline
                         children:@[
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_pauseplay")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"reels_tap_control",
                                                @"value": @"pause",
                                                @"requiresRestart": @YES
                                            }
                             ],
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_muteunmute")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"reels_tap_control",
                                                @"value": @"mute",
                                                @"requiresRestart": @YES
                                            }
                             ]
                         ]
            ]
        ]],

        @"nav_icon_ordering": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:SCILocalized(@"p_menu_default")
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"nav_icon_ordering",
                               @"value": @"default",
                               @"requiresRestart": @YES
                           }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                       identifier:nil
                          options:UIMenuOptionsDisplayInline
                         children:@[
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_classic")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"nav_icon_ordering",
                                                @"value": @"classic",
                                                @"requiresRestart": @YES
                                            }
                             ],
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_standard")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"nav_icon_ordering",
                                                @"value": @"standard",
                                                @"requiresRestart": @YES
                                            }
                             ],
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_alternate")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"nav_icon_ordering",
                                                @"value": @"alternate",
                                                @"requiresRestart": @YES
                                            }
                             ]
                         ]
            ]
        ]],

        @"swipe_nav_tabs": [UIMenu menuWithChildren:@[
            [UICommand commandWithTitle:SCILocalized(@"p_menu_default")
                                  image:nil
                                 action:@selector(menuChanged:)
                           propertyList:@{
                               @"defaultsKey": @"swipe_nav_tabs",
                               @"value": @"default",
                               @"requiresRestart": @YES
                           }
            ],
            [UIMenu menuWithTitle:@""
                            image:nil
                       identifier:nil
                          options:UIMenuOptionsDisplayInline
                         children:@[
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_enabled")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"swipe_nav_tabs",
                                                @"value": @"enabled",
                                                @"requiresRestart": @YES
                                            }
                             ],
                             [UICommand commandWithTitle:SCILocalized(@"p_menu_disabled")
                                                   image:nil
                                                  action:@selector(menuChanged:)
                                            propertyList:@{
                                                @"defaultsKey": @"swipe_nav_tabs",
                                                @"value": @"disabled",
                                                @"requiresRestart": @YES
                                            }
                             ]
                         ]
            ]
        ]]
    };
}

#pragma clang diagnostic pop

@end
