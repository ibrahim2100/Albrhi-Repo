//
//  SCITWPromotedFilter.h
//  Albrhi for Twitter
//
//  The real Promoted Tweet -- not what "Hide ads" was already turning off.
//
//  The seventeen named features include one called "Hide ads", and it does not touch this.
//  It forces off a set of `ssp_ads_*` switches -- third-party ad-SDK integration points, each
//  asked a handful of times a session, the shape of a check made once per screen to decide
//  whether to initialise an ad unit, not once per tweet. **A Promoted Tweet in the home
//  timeline is not gated by any of them.** It is an ordinary `TFNTwitterStatus`, the same
//  class every tweet is, carrying `-isPromoted` = YES and a `-promotedContent` payload sent
//  straight from the server as part of the timeline response. No client switch can make the
//  server stop sending it; the only thing a tweak can do is not draw it once it arrives --
//  the same shape as Instagram's own feed-cleanup features.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Hooks whichever of X's status views this build has. Safe when it has none. Shares its
/// class list with the save-button surface, read from the same TWIGalaxy binary.
void SCITWInstallPromotedFilter(void);

/// How many statuses were checked, and how many were promoted -- read on-device rather than
/// assumed, the same discipline the switch recorder itself was built on. A phone that comes
/// back saying "0 checked" means the hook did not attach to what X is actually building
/// from, not that nobody has seen an ad.
NSString *SCITWPromotedFilterReport(void);

NS_ASSUME_NONNULL_END
