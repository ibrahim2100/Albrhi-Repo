//
//  SCINUSettingsController.h
//  Albrhi Panel
//
//  Albrhi NextUp's settings page, pushed to from the single row SCIPanelScan collapses
//  its seven-process filter down to — the same arrangement Albrhi CarPlay uses, and for
//  the same reason: nine switches cannot live in one switch cell.
//
//  **This page replaces upstream's own Settings bundle.** NextUp 3 shipped a
//  PreferenceLoader pane of its own; the port drops it so every Albrhi tweak is
//  configured from one place. What it does not replace is the mechanism underneath:
//  the injected processes still read exactly what they always read, so this writes to
//  upstream's own CFPreferences domain and publishes upstream's own notify_state token
//  rather than inventing a second channel the tweak would have to learn.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Preferences/PSListController.h>

@interface SCINUSettingsController : PSListController
@end
