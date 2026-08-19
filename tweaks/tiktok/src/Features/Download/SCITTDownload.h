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

/// Saves every picture of a photo post. Called by +save: when the item carries pictures
/// rather than a video; declared so check.py can see the implementation has a home.
/// Saves one picture per group, taking the first link in each group whose bytes actually decode.
///
/// A group is the same picture offered several ways — TikTok served a VVC still on one report, a
/// format iOS cannot read at all, and one link per picture left nothing to fall back to.
+ (void)savePhotos:(NSArray<NSArray<NSURL *> *> *)groups;

/// What the candidate links measured, and which one was taken.
///
/// For the settings screen: a quality report built from *names* could never say whether the
/// chosen link was actually the biggest file, and this one is measured.
extern NSString *SCITTMeasuredReport(void);

@end

/// What the last save attempt actually did, in the words of whatever refused it --
/// an HTTP status, Photos' own reason, or which extension/MIME pair decided a file was
/// audio. For the status screen: "couldn't save it" on a HUD is all a user needs and
/// nothing a fix can be built from.
NSString *SCITTDownloadReport(void);

/// Records that state. Called from the downloader itself; declared here so the
/// status screen and the downloader agree on one source of truth.
void SCITTRecordDownload(NSString *state);

NS_ASSUME_NONNULL_END
