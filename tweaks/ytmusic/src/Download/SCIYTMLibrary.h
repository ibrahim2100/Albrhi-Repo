//
//  SCIYTMLibrary.h
//  Albrhi for YouTube Music
//
//  What has been saved, and playing it.
//
//  **Files on disk, not a database.** A track is an `.m4a` in `Documents/Albrhi` and its name is
//  its metadata. That is deliberate: a store of our own would be a second thing to migrate, to
//  corrupt and to explain, and the one question this screen answers -- *what did I save* -- is
//  answered exactly by listing a folder. Delete one in the Files app and it is gone from here too,
//  which is the behaviour anybody would expect and none of it is code.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTMTrack : NSObject
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *artist;
@property (nonatomic, assign) unsigned long long bytes;
@end

/// Every saved track, newest first.
NSArray<SCIYTMTrack *> *SCIYTMSavedTracks(void);

/// The folder they live in, created if it is not there yet.
NSString *SCIYTMLibraryFolder(void);

/// Plays a track, and tells the system what is playing.
///
/// **The app's own player is not used, and the lock screen does not care.** What makes a track
/// behave like the app's is `MPNowPlayingInfoCenter` and the remote command centre -- the artwork on
/// the Lock Screen, the headphone buttons, Control Centre. Those are given to whoever asks last,
/// which is us while this is playing.
void SCIYTMPlay(SCIYTMTrack *track, NSArray<SCIYTMTrack *> *queue);

/// Whether something of ours is playing, for the row that shows it.
NSURL *_Nullable SCIYTMNowPlayingURL(void);

NS_ASSUME_NONNULL_END
