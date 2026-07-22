#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Runtime diagnostics.
///
/// Two features — the inline download button and the quality picker — depend on
/// Instagram class names that vary between builds. When one silently does nothing
/// there is no way to tell *why* from the UI alone, and guessing at class names
/// from a class dump has already produced two wrong fixes.
///
/// This page reports what is actually true on this device: which classes exist,
/// which hooks attached, and what the last download attempt found. Tapping a row
/// copies the whole report so it can be pasted into an issue.
///

@interface SCIDiagnosticsViewController : UITableViewController
@end

///
/// Facts recorded by features at runtime, read back by the page above.
///

@interface SCIDiagnostics : NSObject

/// Called by the inline button each time it attaches to an action row.
+ (void)recordActionRowClass:(NSString *)className controlCount:(NSInteger)controlCount;

/// Called by the downloader with how many distinct renditions a video offered.
+ (void)recordQualityCount:(NSInteger)count forVideoClass:(nullable NSString *)className;

/// Called by the downloader with the raw DASH manifest a video carried, if any.
///
/// Instagram serves video over DASH and the manifest lists renditions that
/// -videoVersions omits, which is the most likely reason the quality picker has
/// come up short. Nothing parses it yet — this records what the device actually
/// receives so a parser can be written against real data rather than a guess.
/// @param xml    the manifest text, or nil when the objects carried none.
/// @param names  every selector on the video and media objects whose name
///               mentions dash or manifest, as reported by the runtime.
///
/// @c names is the useful half when @c xml is nil: an empty list means the
/// field is not exposed on these classes at all and parsing DASH is a dead end,
/// while a populated list names what to read next.
+ (void)recordDashManifest:(nullable NSString *)xml candidates:(nullable NSArray<NSString *> *)names;

/// Called when the story seen-state uploader is intercepted.
/// What the inline button resolved the post's media to, or nil if it found nothing.
+ (void)recordButtonMediaClass:(nullable NSString *)className;

/// Which branch a download took: "video" or "photo". A photo post reported as
/// video means the emptiness check is failing again.
+ (void)recordDownloadKind:(NSString *)kind;

/// Records one stage of an AV1 transcode (download, demux, decode+encode, mux).
/// The pipeline cannot be tested off-device, so a failure has to name its stage
/// here rather than surface as a blank video. A stage named "download-video"
/// begins a fresh run and clears the previous one.
+ (void)recordTranscodeStage:(NSString *)name ok:(BOOL)ok detail:(nullable NSString *)detail;

+ (void)recordStorySeenIntercept;

/// Which suppressed delegate calls the mark-as-seen button managed to replay.
/// A green tick with nothing replayed means the receipt never left the device.
+ (void)recordSeenReplayBegan:(BOOL)began ended:(BOOL)ended;

/// Walks the live view hierarchy behind the settings sheet looking for anything
/// shaped like a post action row — a view holding several buttons in a line.
///
/// Class-dump names tell you what *exists* in the binary, not what Instagram
/// actually renders. This reports what is on screen right now, which is the only
/// way to know where the download button belongs.
+ (NSArray<NSString *> *)scanForActionRowCandidates;

/// Walks the live hierarchy for labels whose text reads like a timestamp ("2h",
/// "5 d", "January 5") and reports each one's class and its owning superview.
///
/// The custom date format needs somewhere to attach, and Instagram's timestamp
/// classes are not in any header we have. Rather than guess a name — the mistake
/// this project keeps paying for — this reports what is actually on screen, so
/// the hook can be written against a verified class.
+ (NSArray<NSString *> *)scanForTimestampLabels;

/// Called from the date hooks with the formatter that ran and what it produced.
///
/// Which Foundation formatter Instagram uses decides whether custom dates can
/// reach every surface at once. Counting the calls and keeping a few samples
/// answers that from the device instead of from assumption.
+ (void)recordDateFormatter:(NSString *)formatter sample:(nullable NSString *)sample;

@end

NS_ASSUME_NONNULL_END
