//
//  SCITWSpacesBar.h
//  Albrhi for X
//
//  The Spaces bar at the top of the Home timeline, which is what "Hide Spaces" was always
//  about — and was not what two releases of this feature were aiming at.
//
//  0.16.0 excluded the Spaces *tab entry* and 0.16.1 filtered the *tab bar*. Both work as
//  described and neither touched the row of live audio rooms that sits above the timeline,
//  because that is not a tab and never was. The surface is set up by
//  `-_t1_initializeFleets` — named for Fleets, the feature that once occupied that strip —
//  and refusing to run it means the bar is never built at all.
//
//  Confirmed in X 12.20 rather than carried over: the method is `v16@0:8` on
//  `THFHomeTimelineItemsViewController`, which lives in the **main executable**, not in
//  `T1Twitter.framework`. Its older sibling `T1HomeTimelineItemsViewController` is not in
//  this build in any image — hooked anyway, since a `%hook` on an absent class never
//  attaches, and an older X would want it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWSpacesBarReport(void);

void SCITWInstallSpacesBar(void);
