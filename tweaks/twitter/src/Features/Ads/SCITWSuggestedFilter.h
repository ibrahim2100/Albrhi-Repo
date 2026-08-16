//
//  SCITWSuggestedFilter.h
//  Albrhi for Twitter
//
//  Hiding "who to follow" cards wherever X draws one -- experimental, and honest about
//  the one thing this class dump cannot answer.
//
//  `T1UserRecommendationView` is confirmed real: it exists, it takes an account, and it
//  is what draws a suggested-follow card. What is *not* confirmed is where X uses it --
//  a dedicated "Connect" tab someone opens on purpose looks, from this class alone,
//  identical to the same card dropped uninvited into a timeline. Hiding every instance of
//  it is a blunt tool for that reason, and it says so on the settings row rather than
//  promising to hide only the unwanted kind.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

void SCITWInstallSuggestedFilter(void);

NSString *SCITWSuggestedFilterReport(void);
