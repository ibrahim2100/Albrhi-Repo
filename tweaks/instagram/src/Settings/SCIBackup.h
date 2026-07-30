#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Backup & restore of Albrhi's own settings.
///
/// Exports only Albrhi's preference keys — never Instagram's own defaults, which can
/// hold session tokens and personal data — as a JSON file to share or keep, and
/// restores them from such a file. The key list is the single source of truth for
/// "what is ours"; a new feature adds its key there.
///
@interface SCIBackup : NSObject

/// Writes the current Albrhi settings to a JSON file and offers the share sheet.
+ (void)exportFrom:(UIViewController *)presenter;

/// Picks a previously exported file and applies it, then offers a restart.
+ (void)importFrom:(UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
