//
//  SCITWPageController.h
//  Albrhi for X
//
//  One page, pushed from the list.
//
//  It holds nothing but the page it was handed: the sections are rebuilt from that page's
//  own builder every time the screen appears, so a count on a diagnostics row is current
//  rather than whatever it was when somebody first opened the screen.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCITWTable.h"
#import "Model/SCITWPageRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCITWPageController : SCITWTable

- (instancetype)initWithPage:(SCITWPage *)page;

@end

NS_ASSUME_NONNULL_END
