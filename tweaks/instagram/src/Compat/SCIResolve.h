//
//  SCIResolve.h
//  Albrhi for Instagram
//
//  Finding a class Instagram has rewritten in Swift.
//
//  Between 410 and 439, twenty-five of the classes this tweak hooks stopped existing under
//  the names it knows. None of them was renamed and none was deleted: each was rewritten
//  from Objective-C into Swift, which keeps the class name exactly and changes the *runtime*
//  name to carry its module —
//
//      IGDirectComposer    ->  _TtC16IGDirectComposer16IGDirectComposer
//      IGProfileHeaderView ->  _TtC15IGProfileHeader19IGProfileHeaderView
//      IGStoryAdsManager   ->  _TtC17IGStoryAdsManager17IGStoryAdsManager
//
//  All twenty-five were confirmed this way against the 441 binary, and the module differs
//  per class: IGProfileNavigation, IGStoryDefaultFooter, IGGenericSearch. There is no rule
//  that derives it, which is why this searches rather than constructs.
//
//  **Nothing here hard-codes a mangled string.** The numbers in one are the lengths of the
//  module and class names, so a mangled literal is correct only for the build it was copied
//  from — and when Instagram moves a class to another module, a literal stops matching with
//  no error at all. The feature just goes quiet, which is the failure this project has spent
//  the most time chasing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The tweak has .x files and .xm files, and the second kind compiles as Objective-C++.
// C++ mangles function names by their argument types, so a .xm asks the linker for
// SCIResolveClass(NSString*) while SCIResolve.m -- plain Objective-C -- exports plain
// _SCIResolveClass. Nothing complains until the link, and then it complains about four
// files at once and none of them is the one to change.
//
// Methods never have this problem, which is why it has not come up before: every other
// shared piece of this tweak is a class.
#ifdef __cplusplus
extern "C" {
#endif

/// The runtime class for a plain Objective-C class name, whichever form this build has.
///
/// Tries the name as given first, so an older build costs one runtime lookup and no scan.
/// Falls back to a search of every loaded class for a Swift class of the identical name in
/// any module.
///
/// Returns nil when neither exists, which is a real answer and not an error: a class can be
/// gone from a build for the ordinary reason that the feature it served is gone. Callers
/// check, and skip.
Class _Nullable SCIResolveClass(NSString *name);

/// What SCIResolveClass found, for the diagnostics page.
///
/// `nil` means it was never asked. An empty string means it was asked and found nothing —
/// and those two must not look alike. "The hook is not attached" and "the hook is attached
/// and never fired" are different problems with different fixes, and a report that cannot
/// separate them sends everybody looking in the wrong place.
NSString *_Nullable SCIResolvedNameFor(NSString *name);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
