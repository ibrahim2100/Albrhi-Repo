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
/// The first candidate, kept for callers that only want one.
@property (nonatomic, copy) NSURL *url;

/// **Every** http(s) link the resolver found for this item, in the order the chains
/// produced them -- not just the first.
///
/// One chain resolving is not the same as it resolving the *video*: `originURLList`
/// resolved reliably for releases and every file it produced was `audio/mp4` with no
/// video track. A single stored URL leaves nothing to fall back to when that happens.
/// With the whole list kept, the downloader fetches candidates in turn and stops at
/// the first whose downloaded file actually carries a video track -- the file itself
/// deciding, which is the same standard v0.4.12 established for audio-vs-video.
@property (nonatomic, copy) NSArray<NSURL *> *candidates;

/// The pictures of a photo post, in order, or empty for an ordinary video.
///
/// A TikTok photo post is not a video with a still: it is a list of images the app pages
/// through, and saving it means saving all of them. Kept as its own array rather than
/// squeezed into `candidates` -- those are *alternative* links to one thing, and treating a
/// six-picture post as six fallbacks for one file would save the first and call it done.
@property (nonatomic, copy) NSArray<NSURL *> *photoURLs;

/// Which of `photoURLs` the album was showing when this was captured, or `NSNotFound`.
///
/// A photo post of sixteen saved all sixteen without asking, which is not what tapping a
/// download button on one picture means. `AWEPhotoAlbumModel` tracks the swipe itself in
/// `currentIndex`, so the answer is read from the app rather than inferred from the view.
@property (nonatomic, assign) NSUInteger photoIndex;

/// TikTok's own id for this post, or nil.
///
/// Only used by the optional external-HD switch, which is keyed by it. Recorded whether or not
/// that switch is on, because capture must not depend on a preference it would then have to be
/// re-run to pick up — but it is *sent* nowhere unless the switch is on.
@property (nonatomic, copy) NSString *itemID;

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

/// The same, for a model that is known to be **finished**.
///
/// `+captureModel:` is called from `AWEAwemeModel`'s own `-init` hooks, where `-video` is
/// half-built — 0.12.0 crashed the app by walking a list of sub-objects off exactly that. The
/// feed cell's button reaches its model through `AWEFeedCellViewController.model`, which is an
/// object the app has finished with and is currently showing, and only that path may ask the
/// deeper questions: the bitrate ladder, and anything else that means touching the model's
/// children rather than one accessor.
///
/// Two entry points rather than a flag, because "is this object safe to walk" is a fact about
/// the *caller*, and a parameter would let a future caller answer it wrongly.
+ (void)captureSettledModel:(AWEAwemeModel *)model;

/// Every quality gear the last settled video offered, with the chosen one marked.
///
/// For the settings screen. "Is this the highest TikTok has" is a fact about one video on one
/// account, not something this code can reason its way to — so the ladder the app was handed is
/// reported verbatim, and a report then distinguishes "the picker chose wrong" from "there was
/// nothing better on offer".
+ (NSString *)gearLadder;

/// The same resolution `captureModel:` runs, without touching the recent list --
/// for a caller that already has a model in hand and needs its URL right now, such
/// as the in-feed button binding itself to a cell the moment that cell's model is
/// set. Nil on anything the chain could not resolve.
+ (nullable NSURL *)resolveURLForModel:(AWEAwemeModel *)model;

/// Resolves and keeps a URL from an `AWEVideoModel` directly, skipping the aweme model
/// entirely.
///
/// **This is the path that actually works, and it exists because the aweme model's own
/// `-video` is almost always nil when a model is built.** A device report confirmed
/// `AWEVideoModel` is real (`"AWEVideoModel has no -playAddr"` named it outright) and
/// that `-playURL` on it answers a real `AWEURLModel` -- one hop from that class's own
/// doubly-confirmed `-bestURLtoDownload`. Catching the video model at its own
/// construction needs no waiting for `-video` to be populated at all.
+ (void)captureVideoModel:(id)videoModel;

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

/// The same live-runtime dump for any class by name, filtered by any keyword.
///
/// Written for `AWEFeedViewCell`: the in-feed button currently saves whichever URL was
/// resolved *most recently*, which during a scroll is a prefetched neighbour rather
/// than the video on screen -- that is why it downloads the wrong thing and appears
/// inconsistently. Binding it to its own cell's model instead needs that cell's own
/// model accessor, and no reference tweak names one because neither hooks this class.
/// Asking the device is the only way left that is not a guess.
+ (NSString *)accessorsOnClassNamed:(NSString *)className
                            matching:(NSArray<NSString *> *)keywords;

@end

NS_ASSUME_NONNULL_END
