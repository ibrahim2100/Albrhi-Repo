//
//  SCIYTLibrary.h
//  Albrhi for YouTube
//
//  Where downloads live, and what runs them.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import "SCIYTJob.h"
#import "../SCIYTHLS.h"

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main thread whenever anything is added, finishes, or moves.
extern NSNotificationName const SCIYTLibraryDidChangeNotification;

///
/// The downloads, running and finished.
///
/// Downloading used to be a window: a progress alert in front of YouTube, holding the
/// app still for as long as the transfer took, and a save to Photos at the end whether
/// or not that was wanted. Both of those were decisions the download had no business
/// making.
///
/// So the file stays here. It is written into the app's own folder, it appears in the
/// Download Centre the moment it is asked for, and going to Photos is a button next to
/// it rather than the only possible ending. The progress is a row in that list, which
/// means starting a download costs the user nothing -- they carry on watching.
///
/// The folder is the truth and the index is a convenience: a job whose file has been
/// deleted from underneath reports no URL, and the list drops it. Nothing here assumes
/// the two agree.
///
@interface SCIYTLibrary : NSObject

@property (class, nonatomic, readonly) SCIYTLibrary *shared;

/// Where finished files are kept. Created on first use.
+ (NSURL *)folder;

/// Running first, then finished, newest first. One list, because a download in flight
/// and the file it becomes are the same row at two moments.
@property (nonatomic, readonly) NSArray<SCIYTJob *> *jobs;

/// Starts one, and returns immediately. The row appears at once.
- (SCIYTJob *)startVariant:(SCIHLSVariant *)variant
                      kind:(SCIYTJobKind)kind
                     title:(nullable NSString *)title
                   videoID:(nullable NSString *)videoID;

/// Deletes the file and the row.
- (void)remove:(SCIYTJob *)job;

/// Writes the list to disk.
///
/// Public because the player edits a job without going through this class: it records where
/// playback stopped, on the job itself, and that has to survive the app being killed. Call
/// it on the main thread -- it walks the store, which has one thread for the reason set out
/// in -adopt:for:.
- (void)save;

/// Copies a finished download into Photos, leaving ours where it is.
- (void)export:(SCIYTJob *)job completion:(void (^)(BOOL ok, NSString *_Nullable detail))completion;

/// Total size of everything held.
- (long long)totalBytes;

@end

NS_ASSUME_NONNULL_END
