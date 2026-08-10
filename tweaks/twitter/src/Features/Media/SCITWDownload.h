//
//  SCITWDownload.h
//  Albrhi for Twitter
//
//  One way to save a thing, used by every surface that offers to.
//
//  The Instagram tweak learned this the expensive way: before `SCIMediaDownloader` existed,
//  each place that could download built its own call, and a setting applied to one of them
//  and not the others. There is one entry point here from the first release so there is
//  never a second.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCITWMedia.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCITWDownload : NSObject

/// Fetches the item and puts it in Photos, showing progress over whatever is on screen.
///
/// Everything the user sees about the outcome happens in here -- the progress, the tick,
/// the failure and what to do about it. A caller that had to report its own result would be
/// a second place for the wording to drift, and there are three callers already.
///
/// The photo library prompt is X's own: a tweak has no Info.plist of its own, and asking
/// for access is the app asking. Declining is handled as a stated reason rather than as a
/// silent nothing, which is what the first version did.
+ (void)save:(SCITWMediaItem *)item;

@end

NS_ASSUME_NONNULL_END
