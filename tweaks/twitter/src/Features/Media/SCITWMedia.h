//
//  SCITWMedia.h
//  Albrhi for Twitter
//
//  What X has shown you lately, and where the file for it is.
//
//  ## Why there is no button in X
//
//  There is no download button added to a post, and that is a decision rather than a
//  shortcut. A button has to live inside one of X's views, and X's views are renamed
//  between releases -- which is the failure this whole tweak is built to avoid, and which
//  Instagram's reels button cost this project twice. The YouTube tweak reached the same
//  conclusion for the same reason and put its downloads in a screen of its own.
//
//  So the capture is at the model. `TFSTwitterMediaInfo` is what X builds whenever a piece
//  of media is about to be shown -- in the timeline, full screen, inside a quoted post, in
//  a direct message -- and one hook there sees all four. What you looked at is in the list;
//  hold two fingers and it is at the top.
//
//  Nothing here is a copy of the media. It is the URL X itself resolved, kept until the app
//  closes.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCITWMediaKind) {
    SCITWMediaKindImage = 0,
    SCITWMediaKindVideo = 1,
    SCITWMediaKindGif   = 2,
};

/// One thing that can be saved.
@interface SCITWMediaItem : NSObject

/// X's own identifier for the media, and what makes the list a list rather than the same
/// video forty times -- a timeline that scrolls past a post repeatedly rebuilds its model
/// each time.
@property (nonatomic, copy) NSString *identifier;

@property (nonatomic, assign) SCITWMediaKind kind;

/// The file to fetch. Already chosen: for a video this is the best MP4 X offers, resolved
/// at capture time rather than when the row is tapped, so a tap saves instead of thinking.
@property (nonatomic, copy) NSURL *url;

/// Seconds, zero for a still.
@property (nonatomic, assign) double duration;

/// The image's alt text when it has one. The nearest thing to a caption X gives us, and
/// better than "Video" repeated eleven times down a list.
@property (nonatomic, copy, nullable) NSString *note;

@property (nonatomic, strong) NSDate *seen;

/// The file extension the saved file should carry, derived from the URL rather than assumed
/// -- Photos rejects a video handed to it under the wrong extension, and does so quietly.
@property (nonatomic, readonly) NSString *fileExtension;

@end


@interface SCITWMedia : NSObject

/// Reads one of X's media objects and remembers it if it is something that can be saved.
///
/// Takes `id` on purpose. The caller is a hook whose argument is whatever X handed it, and
/// this method is the one place that decides whether the object is usable -- checking that
/// it can do its job rather than that it is non-nil, which on Instagram was the difference
/// between a working download button and one on every photo in the feed.
+ (void)capture:(id)mediaEntity;

/// Reads one of X's media objects into an item, or returns nil when it is not something
/// that can be saved -- a photo post whose `-videoInfo` is a hollow object, a live
/// broadcast that offers a stream and no file.
///
/// Split out from `-capture:` so the in-video button can build an item for the one thing a
/// person tapped without going through the remembered list, and so both paths decide
/// "saveable" by the same rules. Takes `id` for the same reason `-capture:` does: the
/// caller is a hook holding whatever X handed it, and this is the one place that checks.
+ (nullable SCITWMediaItem *)itemForEntity:(id)mediaEntity;

/// Newest first, at most `SCITWMediaLimit`.
+ (NSArray<SCITWMediaItem *> *)recent;

+ (void)forgetAll;

@end

NS_ASSUME_NONNULL_END
