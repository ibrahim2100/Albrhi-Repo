#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The confirmation every "are you sure" in Albrhi goes through.
///
/// There are eleven of these — liking a reel, refreshing the feed, following
/// someone, changing a theme — and each one used to raise a stock system alert
/// titled in hard-coded English, untranslated, with a button reading "No!". They
/// are the tweak's most-seen surface and read as the least considered part of it.
///
/// One sheet now serves all of them: the same card, blur and spring as the rest of
/// Albrhi's own UI, in whichever language the user chose. Call sites are unchanged —
/// SCIUtils' showConfirmation: routes here — so a new confirmation gets the look for
/// free.
///
@interface SCIConfirmSheet : NSObject

/// @param title    what is about to happen, or nil for a plain "are you sure".
/// @param symbol   an SF Symbol shown above it, or nil for a default.
/// @param confirm  run when the user agrees.
/// @param cancel   run when they do not, including on a tap outside.
+ (void)presentWithTitle:(nullable NSString *)title
                  symbol:(nullable NSString *)symbol
                 confirm:(void (^)(void))confirm
                  cancel:(nullable void (^)(void))cancel;

@end

NS_ASSUME_NONNULL_END
