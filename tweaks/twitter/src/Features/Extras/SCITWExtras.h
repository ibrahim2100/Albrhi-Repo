//
//  SCITWExtras.h
//  Albrhi for X
//
//  The small answers: one question each, one hook each, nothing drawn.
//
//  Every one of these is X asking itself something and this tweak answering differently --
//  the shape the switch layer already uses, applied to questions that are methods rather
//  than feature-switch keys. That is why they are grouped: not because they are related to
//  each other, but because each is three lines and a confirmed encoding.
//
//  **Three of BHTwitter's are not here, and their absence is the finding rather than an
//  omission.** `_t1_showPremiumUpsellIfNeeded`, `-isVODCaptionsEnabled` and
//  `TFNTableView -setShowsVerticalScrollIndicator:` are not in X 12.20 at all -- checked
//  against the app's own class metadata, not assumed. A reference tweak's list is a map of
//  the build it was written for, which this project has now paid for on three apps.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWExtrasReport(void);
void SCITWInstallExtras(void);
