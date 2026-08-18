//
//  SCITTStillVideo.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// One picture plus the post's sound, written as a video.
///
/// A TikTok photo post is a slideshow with music, and saving a picture from it throws the music
/// away -- which is most of what made the post. This writes the chosen picture as a still video of
/// a chosen length with that sound over it, which is what the Instagram tweak already does for the
/// same reason.
///
/// **Two steps rather than one, and the reason is that neither step is the hard one people expect.**
/// `AVAssetWriter` can write a still into a video track but has to be fed audio sample by sample;
/// `AVAssetExportSession` handles audio properly but cannot invent a video track from a `UIImage`.
/// So the picture becomes a silent video first, and a composition then lays the trimmed sound over
/// it and exports the pair. Each half is then the thing its own API is for.
///
@interface SCITTStillVideo : NSObject

/// Writes `image` for `seconds` with the audio at `audioURL` over it, then hands back a file URL.
///
/// `completion` runs on an arbitrary queue with either a URL or a reason -- never both nil, so a
/// caller reporting failure always has something to report.
+ (void)renderImage:(UIImage *)image
           audioURL:(NSURL *)audioURL
            seconds:(NSTimeInterval)seconds
         completion:(void (^)(NSURL *file, NSString *failure))completion;

@end
