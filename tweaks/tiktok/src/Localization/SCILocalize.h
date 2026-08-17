#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The string for `key` in the device's language, English otherwise, or the key itself
/// if nothing else answers -- so a missing translation is visible instead of blank.
NSString *SCILocalized(NSString *key);

NS_ASSUME_NONNULL_END
