#import <UIKit/UIKit.h>

///
/// Albrhi's own panel, presented over YouTube rather than built inside its settings.
///
/// Two attempts were made at putting a section into YouTube's own settings screen.
/// The first added a category to a list the screen no longer reads, so nothing
/// appeared. The second reached the list it does read, and YouTube crashed on opening
/// Settings — because announcing a category is a contract with tables we do not have:
/// a title, an icon, a page identifier, and a delegate reached through an ivar that
/// has no getter.
///
/// The reference tweak studied for hook points does not do it either. It carries its
/// own options controller and its own way in. That is not a workaround, it is the
/// correct shape: a panel we own cannot be broken by a settings model we do not.
///
@interface SCIYTPanel : NSObject

/// Presents the panel from whatever is currently on screen. Safe to call when
/// something is already being presented — it declines rather than throwing.
+ (void)present;

@end
