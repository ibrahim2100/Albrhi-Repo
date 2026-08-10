#import <Foundation/Foundation.h>

/// The version this build was made from, defined once in Tweak.x.
///
/// Kept in step with `control` by tools/check.py, which fails the build when the two
/// disagree -- a report that names the wrong version is worse than one that names none,
/// because it is believed.
extern NSString *SCIVersionString;
