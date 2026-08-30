#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../SCIYTTabBarController.h"

///
/// Parts of YouTube's own screen you can switch off.
///
/// Its own page rather than rows scattered through the others, because these share a
/// property nothing else here has: each one *removes* something that works. An ad blocker
/// takes away something nobody wanted; this takes away something somebody might. Keeping
/// them together, under one heading, means turning any of them on is a deliberate act rather
/// than a switch stumbled over while looking for something else.
///
/// Every one ships off. See `Features/Interface/SCIYTHide.x` for how each is done — none of
/// them hides a view; they answer the question the app asks before building it.
///
@interface SCIYTInterfacePage : NSObject
@end

@implementation SCIYTInterfacePage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:35
                                        title:SCILocalized(@"page_interface")
                                       detail:SCILocalized(@"page_interface_note")
                                       symbol:@"eye.slash"
                                      builder:^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *host) {
        SCISection *player = [[SCISection alloc] init];
        player.title = SCILocalized(@"section_hide_player");
        player.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_ambient_glow")
                       detail:SCILocalized(@"hide_ambient_glow_note")
                       symbol:@"light.max"
                      prefKey:SCIPrefHideAmbient],
            [SCIRow switchRow:SCILocalized(@"hide_endscreen")
                       detail:SCILocalized(@"hide_endscreen_note")
                       symbol:@"rectangle.grid.2x2"
                      prefKey:SCIPrefHideEndscreen],
            [SCIRow switchRow:SCILocalized(@"hide_info_cards")
                       detail:SCILocalized(@"hide_info_cards_note")
                       symbol:@"info.circle"
                      prefKey:SCIPrefHideInfoCards],
        ];

        SCISection *tabs = [[SCISection alloc] init];
        tabs.title = SCILocalized(@"section_tab_bar");
        tabs.footer = SCILocalized(@"section_tab_bar_note");
        tabs.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_tabs_arrange")
                           detail:SCILocalized(@"set_tabs_arrange_note")
                           symbol:@"square.grid.2x2"
                           action:^{ [SCIYTTabBarController present]; }],
        ];

        SCISection *bar = [[SCISection alloc] init];
        bar.title = SCILocalized(@"section_hide_topbar");
        bar.footer = SCILocalized(@"section_hide_topbar_note");
        bar.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_search_button")
                       detail:nil
                       symbol:@"magnifyingglass"
                      prefKey:SCIPrefHideSearchButton],
            [SCIRow switchRow:SCILocalized(@"hide_notify_button")
                       detail:nil
                       symbol:@"bell"
                      prefKey:SCIPrefHideNotifyButton],
            [SCIRow switchRow:SCILocalized(@"hide_create_button")
                       detail:nil
                       symbol:@"plus.circle"
                      prefKey:SCIPrefHideCreateButton],
            [SCIRow switchRow:SCILocalized(@"hide_cast_button")
                       detail:nil
                       symbol:@"tv.badge.wifi"
                      prefKey:SCIPrefHideCastButton],
        ];

        SCISection *elsewhere = [[SCISection alloc] init];
        elsewhere.title = SCILocalized(@"section_hide_elsewhere");
        elsewhere.rows = @[
            [SCIRow switchRow:SCILocalized(@"hide_share_promo")
                       detail:SCILocalized(@"hide_share_promo_note")
                       symbol:@"square.and.arrow.up"
                      prefKey:SCIPrefHideSharePromo],
        ];

        // Added rather than hidden, which is what every other row on this page does.
        //
        // Both act on classes this project has not confirmed on a device -- read from
        // YTVideoOverlay (MIT) rather than from a class dump -- so they default off and the
        // diagnostics report names which of the two attached.
        SCISection *overlay = [[SCISection alloc] init];
        overlay.title = SCILocalized(@"overlay_header");
        overlay.rows = @[
            [SCIRow switchRow:SCILocalized(@"overlay_button_title")
                       detail:SCILocalized(@"overlay_button_note")
                       symbol:@"arrow.down.circle"
                      prefKey:SCIPrefOverlayButton],
            [SCIRow switchRow:SCILocalized(@"overlay_endtime_title")
                       detail:SCILocalized(@"overlay_endtime_note")
                       symbol:@"clock"
                      prefKey:SCIPrefOverlayEndTime],
        ];

        return @[player, tabs, bar, overlay, elsewhere];
    }];
}

@end
