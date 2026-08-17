//
//  SCITTMedia.h
//  Albrhi for TikTok
//
//  The videos this tweak has actually resolved a download URL for, so one can be saved.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

@class AWEAwemeModel;

NS_ASSUME_NONNULL_BEGIN

@interface SCITTMediaItem : NSObject
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, copy) NSDate *seen;
@end


@interface SCITTMedia : NSObject

/// Resolves a download URL for `model` right here, synchronously, and keeps only the
/// URL -- never the model itself. TikTok's own feed cells recycle constantly and this
/// tweak has no business extending how long one of its objects stays alive; a plain
/// URL costs nothing to hold and cannot interfere with anything.
///
/// Every step of `model.videoModel.playAddr.bestURLtoDownload` is guarded with
/// `-respondsToSelector:` before it is sent, because only `-isAds` and
/// `AWEURLModel`'s own method are confirmed the way this project requires -- the
/// property that reaches from a model to its video is read from where its name and
/// ivar sit in the binary's own string table, not from a hooked selector two
/// independent reference tweaks both call. A step that does not answer is recorded,
/// not guessed past.
+ (void)captureModel:(AWEAwemeModel *)model;

/// Newest first, at most a small cap.
+ (NSArray<SCITTMediaItem *> *)recent;

+ (void)forgetAll;

/// What the resolution chain last did -- which step it reached, and where it stopped
/// if it did. For the status screen's own report.
+ (NSString *)lastAttemptState;

@end

NS_ASSUME_NONNULL_END
