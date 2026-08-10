//
//  TwitterHeaders.h
//  Albrhi for Twitter
//
//  Every X class this tweak touches, declared.
//
//  Taken from the class dump of 12.15 and named exactly as the runtime names them. These
//  are declarations of what is already in the app, not definitions -- nothing here is
//  implemented, and a class the running build does not have simply never gets hooked,
//  because every hook is behind a `%group` that is initialised only if `NSClassFromString`
//  finds it.
//
//  **They do not live in X's main binary.** `com.atebits.Tweetie2` is 10,827 classes over
//  58 Mach-O images: `T1*` in T1Twitter.framework, `TFS*` and `TAE*` in TwitterSPMMigration
//  and TwitterAppSPMMigration. Anything that looks for them by scanning the executable
//  finds none of them.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// One encoding of one video: a URL, what kind of file it is, and how good it is.
///
/// X keeps several per video -- the same content at different bitrates, plus a streaming
/// playlist -- which is why the downloader picks rather than takes the first.
@interface TFSTwitterEntityMediaVideoVariant : NSObject
@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *contentType;
@property (nonatomic, readonly) long long bitrate;
@end


@interface TFSTwitterEntityMediaVideoInfo : NSObject
@property (nonatomic, readonly) NSArray<TFSTwitterEntityMediaVideoVariant *> *variants;
@property (nonatomic, readonly) double duration;

/// **X's own picker, and the reason this tweak does not write one.**
///
/// Asking the app to choose means the choice is whatever X considers best for that content
/// type, on this build, including whatever rules it has that are not visible from outside.
/// A hand-rolled "highest bitrate wins" loop would be right most of the time and wrong
/// silently the rest — and this project has already paid three times for reimplementing a
/// selection stage instead of measuring the one that exists.
///
/// It is still only asked, never trusted: the caller falls back to walking `variants`
/// itself when this returns nothing, because a private method that changes shape is a real
/// possibility and a download that quietly stops working is not acceptable.
- (NSString *)highestBitrateVideoVariantURLWithContentType:(NSString *)contentType
                                        andMaximumBitrate:(long long)maximumBitrate;
@end


@interface TFSTwitterEntityMedia : NSObject
@property (nonatomic, readonly) TFSTwitterEntityMediaVideoInfo *videoInfo;
@property (nonatomic, readonly) NSString *mediaID;
@property (nonatomic, readonly) NSString *mediaKey;
@property (nonatomic, readonly) NSURL *mediaURL;
@property (nonatomic, readonly) NSString *imageURLString;
@property (nonatomic, readonly) NSString *altText;
@property (nonatomic, readonly) long long mediaType;

/// X's own answers about what this object is, asked rather than inferred.
///
/// The lesson from Instagram, where `IGMedia.video` returns a hollow `IGVideo` for a photo
/// post: a non-nil object is not a working object. `-isVideo` and `-videoInfo` disagreeing
/// is exactly the case that produced a download button on every photo in the feed.
- (BOOL)isVideo;
- (BOOL)isAnimatedGif;
- (BOOL)isImage;
- (BOOL)isPlayable;
- (BOOL)isDeadVideo;
@end


/// The wrapper X builds when a piece of media is about to be shown.
///
/// Hooked instead of a view, because it is the model: the timeline, the full-screen viewer,
/// a quoted post and a direct message all build one of these, and one hook here sees media
/// from all four. Hooking the four views would be four hooks that each break separately.
@interface TFSTwitterMediaInfo : NSObject
@property (nonatomic, strong) TFSTwitterEntityMedia *mediaEntity;
@property (nonatomic, readonly) TFSTwitterEntityMediaVideoInfo *videoInfo;
@end
