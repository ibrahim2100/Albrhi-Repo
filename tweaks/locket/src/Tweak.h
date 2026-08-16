#import <UIKit/UIKit.h>

/// The version this build was made from, defined once in Tweak.x and kept in step with
/// `control` by tools/check.py.
extern NSString *SCIVersionString;

///
/// This tweak's accent, in one place -- the same reason the other tweaks in this
/// repository each keep one rather than writing the same three floats out per screen.
///
/// A warm amber rather than any other tweak's colour: Locket's own app icon and its
/// send/receive flash are both this family of gold, so a screen using it reads as
/// belonging to Locket specifically rather than to Albrhi generically.
static inline UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:1.0 green:0.72 blue:0.19 alpha:1.0];
}
