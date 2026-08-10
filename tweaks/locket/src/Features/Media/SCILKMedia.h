//
//  SCILKMedia.h
//  Albrhi for Locket
//
//  The moments Locket has fetched, so one can be saved to Photos.
//
//  Locket is a Swift app and a moment is a Swift struct — invisible to an Objective-C hook,
//  which is why the model cannot be read the way the X tweak reads a tweet's media. What is
//  reachable is the network: every moment's photo or video is a blob in Firebase Storage,
//  and the app fetches it through NSURLSession, which is Objective-C and hookable. So the
//  capture is at the request, exactly where LocketLRD put it.
//
//  ## What is captured, and what is left out
//
//  Only the two storage hosts Locket serves user media from, and only the private objects:
//  the public buckets hold filter art, overlays and invites, which are decoration rather
//  than a moment a friend sent. Excluding them by the "public" in their path is what keeps
//  the list moments and not a wall of UI assets. Nothing is copied — it is the URL Locket
//  itself requested, kept until the app closes.
//
//  Saving a moment a friend sent you to your own Photos is the same footing as the X and
//  Instagram download buttons: the image is already on the device, and a screenshot does
//  the same thing more clumsily. It does not touch Locket's paid features.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCILKMediaItem : NSObject
/// The blob to fetch. Opaque — a Firebase object path and a signed token — so the kind of
/// media is not knowable from it and is decided from the response when it is saved.
@property (nonatomic, copy) NSURL *url;
/// The host, shown so a person can see where it came from.
@property (nonatomic, copy) NSString *host;
/// A short, readable tail of the object path, since the full URL is a token nobody reads.
@property (nonatomic, copy) NSString *label;
@property (nonatomic, strong) NSDate *seen;
@end


@interface SCILKMedia : NSObject

/// Reads one of Locket's requests and remembers its URL if it points at a user moment.
/// Takes the request rather than the URL so the host and path can be judged together, and
/// does nothing for anything that is not a private storage blob.
+ (void)captureRequest:(NSURLRequest *)request;

/// Newest first, at most the cap.
+ (NSArray<SCILKMediaItem *> *)recent;

+ (void)forgetAll;

@end

NS_ASSUME_NONNULL_END
