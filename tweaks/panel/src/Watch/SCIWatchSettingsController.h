//
//  SCIWatchSettingsController.h
//  Albrhi Panel
//
//  Albrhi Watch's settings page, pushed to from the single row SCIPanelScan collapses its
//  filter down to.
//
//  **The page carries a respring button, which no other tweak's page here does.** Every switch
//  on it changes what SpringBoard answers while pairing, and SpringBoard reads those answers
//  when its hooks are installed — at launch. So a switch moved here does nothing until the
//  process restarts, and a page that hides that fact is a page that reports success while
//  nothing has changed.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Preferences/PSListController.h>

@interface SCIWatchSettingsController : PSListController
@end
