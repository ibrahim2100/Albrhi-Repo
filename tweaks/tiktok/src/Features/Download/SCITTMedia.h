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

/// The same resolution `captureModel:` runs, without touching the recent list --
/// for a caller that already has a model in hand and needs its URL right now, such
/// as the in-feed button binding itself to a cell the moment that cell's model is
/// set. Nil on anything the chain could not resolve.
+ (nullable NSURL *)resolveURLForModel:(AWEAwemeModel *)model;

/// Newest first, at most a small cap.
+ (NSArray<SCITTMediaItem *> *)recent;

+ (void)forgetAll;

/// What the resolution chain last did -- which step it reached, and where it stopped
/// if it did. For the status screen's own report.
+ (NSString *)lastAttemptState;

/// Every property and no-argument method on `AWEAwemeModel` and its superclasses
/// (up a few levels) whose name contains "video", "play", "url", "media", "cover",
/// "download" or "aweme" -- read from the live runtime class on this exact device,
/// not from a class dump taken somewhere else. For when a guessed accessor like
/// `-videoModel` turns out not to exist on a build: this answers what the real one
/// is actually named, on the build it needs to be named on.
+ (NSString *)candidateAccessorsOnAwemeModel;

@end

NS_ASSUME_NONNULL_END
