//
//  SCILKDownload.h
//  Albrhi for Locket
//
//  One way to save a moment, and the only one.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCILKMedia.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCILKDownload : NSObject

/// Fetches the moment and puts it in Photos, showing progress over whatever is on screen.
///
/// Locket's URLs are opaque, so the kind — photo or video — is not known in advance; it is
/// read from the response's content type and the file is saved and named accordingly.
/// Everything the user sees about the outcome happens in here, so there is one place the
/// wording lives.
+ (void)save:(SCILKMediaItem *)item;

@end

NS_ASSUME_NONNULL_END
