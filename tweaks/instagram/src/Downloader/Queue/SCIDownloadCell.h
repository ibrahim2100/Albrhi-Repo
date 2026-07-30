#import <UIKit/UIKit.h>
#import "SCIDownloadJob.h"

NS_ASSUME_NONNULL_BEGIN

@class SCIDownloadCell;

@protocol SCIDownloadCellDelegate <NSObject>
/// The trailing control was tapped — pause, resume or retry depending on state.
- (void)downloadCellDidTapAction:(SCIDownloadCell *)cell;
@end

///
/// A single download row.
///
/// Layout is a tinted glyph tile, a two-line label stack, and a trailing control
/// that doubles as the progress indicator: a ring that fills as bytes arrive,
/// with the pause/resume/retry glyph at its centre.
///

@interface SCIDownloadCell : UITableViewCell

@property (nonatomic, weak) id<SCIDownloadCellDelegate> delegate;
@property (nonatomic, strong, readonly) SCIDownloadJob *job;

+ (NSString *)reuseIdentifier;

- (void)configureWithJob:(SCIDownloadJob *)job accentColor:(UIColor *)accent;

/// Updates only the parts that change during a transfer, so an in-flight row can
/// refresh without a full reload (and without interrupting a swipe).
- (void)applyProgressFromJob:(SCIDownloadJob *)job;

@end

NS_ASSUME_NONNULL_END
