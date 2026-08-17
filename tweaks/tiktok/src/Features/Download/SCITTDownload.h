//
//  SCITTDownload.h
//  Albrhi for TikTok
//
//  One way to save a video, and the only one.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCITTMedia.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCITTDownload : NSObject

/// Fetches the video and puts it in Photos, showing progress over whatever is on screen.
+ (void)save:(SCITTMediaItem *)item;

@end

NS_ASSUME_NONNULL_END
