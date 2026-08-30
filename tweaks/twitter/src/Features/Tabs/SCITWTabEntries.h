//
//  SCITWTabEntries.h
//  Albrhi for Twitter
//
//  Which tabs the bottom bar carries, decided where X decides it.
//
//  Two switches were reported as doing nothing on a device, and the 0.15.0 report said why
//  rather than leaving it to guesswork. "Hide Spaces" answered
//  `voice_rooms_consumption_enabled` **784 times** and the tab stayed; "More tabs" answered
//  `ios_tab_bar_default_show_communities` **twice**, and that key's own name carries
//  `default` -- it seeds the bar a new account starts with, so a saved configuration wins
//  every time afterwards. Neither switch was failing to apply. Both were the wrong lever.
//
//  The right one was read out of X 12.20's own class metadata, not guessed: every tab is an
//  `…AppNavigationTabEntry`, and all of them -- Home, Communities, Profile, Voice, Grok,
//  fifteen more -- answer `-isExcludedFromTabBar` (`B16@0:8`) and `-isTabViewSideBarOnly`.
//  One BOOL per tab, asked by X itself, which is the same shape as hooking the feature
//  switch rather than the fifty-one views that read it.
//
//  **The classes are Swift and are bound by their mangled runtime names**, the way the
//  immersive rail already is here. A `%hook` on a class this build does not carry never
//  attaches, so naming one costs nothing -- but silence then looks identical to a hook that
//  attached and was never consulted, and that ambiguity has cost this project releases. So
//  each entry counts its own calls and the report separates "not in this build" from
//  "hooked, never asked" from "hooked, answered N times".
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// One line per tab entry: whether it is in this build, and what it was asked.
NSString *SCITWTabEntriesReport(void);

void SCITWInstallTabEntries(void);
