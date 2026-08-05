//
//  SCIYTSubpageController.h
//  Albrhi for YouTube
//
//  One registered page, on a screen of its own.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIYTSectionsController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTSubpageController : SCIYTSectionsController

/// The page whose sections this screen shows. Its own title becomes the navigation title.
- (instancetype)initWithPage:(SCIYTPage *)page;

@end

NS_ASSUME_NONNULL_END
