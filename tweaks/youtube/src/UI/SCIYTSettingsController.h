#import <UIKit/UIKit.h>
#import "SCIYTSectionsController.h"
#import "../Settings/SCIYTSettingsRegistry.h"

///
/// Albrhi's settings screen.
///
/// A UITableViewController, and that is the load-bearing decision in this file.
///
/// Three releases in a row either failed to appear or crashed, and the last one died
/// inside CoreAutoLayout while building a panel out of hand-written constraints. A
/// grouped table has almost no constraint surface: rows are sized by the system, the
/// header is measured once, and there is nothing to relate to the wrong ancestor. The
/// fix for an unsatisfiable layout is fewer constraints, and the fewest available is
/// the ones UIKit writes itself.
///
/// Presented in its own navigation controller, over YouTube, rather than pushed into
/// YouTube's settings. Two attempts at the latter established that announcing a
/// settings category is a contract with tables this tweak has no access to.
///
/// **It holds no settings of its own.** Every one lives on a page, and this is the list of
/// pages -- see SCIYTSectionsController for the table both screens are.
///
@interface SCIYTSettingsController : SCIYTSectionsController

/// Presents it from whatever is on screen. Guarded: a settings screen that cannot be
/// built must fail to open, not take YouTube down with it.
+ (void)present;

@end
