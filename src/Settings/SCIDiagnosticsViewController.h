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

/// Called when the story seen-state uploader is intercepted.
+ (void)recordStorySeenIntercept;

/// Walks the live view hierarchy behind the settings sheet looking for anything
/// shaped like a post action row — a view holding several buttons in a line.
///
/// Class-dump names tell you what *exists* in the binary, not what Instagram
/// actually renders. This reports what is on screen right now, which is the only
/// way to know where the download button belongs.
+ (NSArray<NSString *> *)scanForActionRowCandidates;

@end

NS_ASSUME_NONNULL_END
