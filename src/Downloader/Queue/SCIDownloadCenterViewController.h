#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Download Center.
///
/// Two sections — in-flight transfers and history — with search, media-kind
/// scoping, sorting, per-row swipe actions and context menus, and bulk controls
/// in the toolbar.
///
/// Rows update in place while downloading: only the affected cell is touched, so
/// a live transfer never interrupts scrolling or an open swipe action.
///

@interface SCIDownloadCenterViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
