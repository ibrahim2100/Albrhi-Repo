#import <UIKit/UIKit.h>

/// The tweak's version, matched against control by tools/check.py so a release can
/// never ship a binary that disagrees with its own package.
extern NSString *SCIVersionString;

///
/// The tweak's accent, in one place.
///
/// It was written out as a static function in eight separate files -- the settings screen,
/// the player, the mini bar, the Centre page, the list, the sheet, the tab and the welcome
/// screen -- all returning the same three numbers. Eight copies of a constant is eight
/// chances for one of them to drift, and someone changing the colour would have found seven
/// of them and shipped a tweak with two reds in it.
///
/// Inline in the header rather than a symbol in some .m: it is three floats, every caller
/// wants it at draw time, and a cross-file call for a colour is not worth the linkage.
///
static inline UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.0 blue:0.13 alpha:1.0];
}
