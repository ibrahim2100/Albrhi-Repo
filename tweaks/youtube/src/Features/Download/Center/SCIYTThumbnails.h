//
//  SCIYTThumbnails.h
//  Albrhi for YouTube
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCIYTJob.h"

NS_ASSUME_NONNULL_BEGIN

///
/// A still from each saved video, and how long it runs.
///
/// Both are read out of the file, and reading a file is not something a table cell may
/// do while it is being drawn: thirty rows would open thirty assets on the main thread
/// and the list would stutter before it appeared. So both are produced away from it and
/// handed back when they are ready, and both are kept -- the picture as a small JPEG
/// beside the video, the length on the job itself.
///
/// The cache lives in a dot-folder inside the downloads folder. That folder is visible
/// in Files, and someone looking at their own videos there should not be shown a pile of
/// thumbnails they never asked for.
///
@interface SCIYTThumbnails : NSObject

/// The still for this download, if one has already been made. Cheap; safe on the main
/// thread; nil when there is not one yet.
+ (nullable UIImage *)cached:(SCIYTJob *)job;

/// Makes one if it is missing, and measures the file while it is open. Calls back on the
/// main thread, once, only if something was actually produced.
+ (void)prepare:(SCIYTJob *)job completion:(void (^)(UIImage *_Nullable image))completion;

/// Deletes the still for a download that has been removed.
+ (void)forget:(SCIYTJob *)job;

/// "3:02", "1:04:11".
+ (NSString *)clock:(double)seconds;

@end

NS_ASSUME_NONNULL_END
