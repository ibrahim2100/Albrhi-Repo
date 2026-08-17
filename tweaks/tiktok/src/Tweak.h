#import <UIKit/UIKit.h>

/// The version this build was made from, defined once in Tweak.x and kept in step with
/// `control` by tools/check.py.
extern NSString *SCIVersionString;

///
/// This tweak's accent, in one place -- the same reason every other tweak in this
/// repository keeps one rather than writing the same three floats out per screen.
///
/// TikTok red, not any other tweak's colour, so a screen using it reads as belonging to
/// this tweak specifically.
static inline UIColor *SCIAccent(void) {
    return [UIColor colorWithRed:0.996 green:0.176 blue:0.333 alpha:1.0];
}
