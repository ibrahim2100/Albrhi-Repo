//
//  SCILocalizeAPI.h
//  The one declaration this kit needs from whichever bundle is compiling it.
//
//  These files used to live inside Albrhi Panel and import its own
//  `Localization/SCILocalize.h` by a relative path. Three preference bundles share them
//  now — the panel, Albrhi NextUp and Albrhi Watch — and each carries its own table, so
//  the shared code declares the function and lets the bundle supply it. Importing a path
//  that happens to resolve differently per include order is how a shared file silently
//  reads the wrong table.
//

#import <Foundation/Foundation.h>

/// The string for `key` in the device's language, English where there is no Arabic.
/// Defined by whichever bundle compiles this kit — each has its own table.
NSString *SCILocalized(NSString *key);
