#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIDownloadState) {
    SCIDownloadStateQueued,      // waiting for a free slot
    SCIDownloadStateDownloading,
    SCIDownloadStatePaused,      // suspended by the user, resume data retained
    SCIDownloadStateCompleted,
    SCIDownloadStateFailed,
    SCIDownloadStateCancelled
};

typedef NS_ENUM(NSInteger, SCIDownloadMediaKind) {
    SCIDownloadMediaKindUnknown,
    SCIDownloadMediaKindPhoto,
    SCIDownloadMediaKindVideo,
    SCIDownloadMediaKindAudio
};

///
/// A single unit of work in the download queue.
///
/// Jobs outlive the app session: completed and failed jobs are persisted as
/// history, so `NSSecureCoding` covers every field the history view needs.
/// Live-only state (the URLSession task, resume data) is deliberately excluded.
///

@interface SCIDownloadJob : NSObject <NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSURL *remoteURL;
@property (nonatomic, copy, readonly) NSString *fileExtension;
@property (nonatomic, copy) NSString *displayName;

/// Where the media came from — "@username", "Reel", "Story". Shown as the subtitle.
@property (nonatomic, copy, nullable) NSString *sourceLabel;

@property (nonatomic, readonly) SCIDownloadMediaKind mediaKind;
@property (nonatomic) SCIDownloadState state;

@property (nonatomic) float progress;            // 0.0 – 1.0
@property (nonatomic) int64_t bytesReceived;
@property (nonatomic) int64_t bytesExpected;     // NSURLSessionTransferSizeUnknown when the server won't say
@property (nonatomic) double bytesPerSecond;

@property (nonatomic, copy, readonly) NSDate *createdAt;
@property (nonatomic, copy, nullable) NSDate *finishedAt;

/// Where the finished file landed on disk. Nil until completion.
@property (nonatomic, copy, nullable) NSURL *localURL;
@property (nonatomic, copy, nullable) NSString *failureReason;

/// Incremented by `retry`, so a job that keeps failing can be spotted.
@property (nonatomic) NSInteger attemptCount;

/// Set once the file has been written to the photo library. Persisted, so a job
/// that finished while the app was backgrounded is not saved twice — or missed.
@property (nonatomic) BOOL savedToPhotos;

+ (instancetype)jobWithURL:(NSURL *)url
             fileExtension:(nullable NSString *)fileExtension
               displayName:(nullable NSString *)displayName
               sourceLabel:(nullable NSString *)sourceLabel;

// MARK: - Presentation

/// "4.2 MB of 12.8 MB · 1.4 MB/s", "Paused · 4.2 MB", "Failed — timed out", …
- (NSString *)statusDescription;

/// SF Symbol representing the media kind.
- (NSString *)symbolName;

- (BOOL)isActive;    // queued, downloading or paused
- (BOOL)isFinished;  // completed, failed or cancelled

@end

NS_ASSUME_NONNULL_END
