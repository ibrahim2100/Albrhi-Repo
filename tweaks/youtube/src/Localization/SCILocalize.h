#import <Foundation/Foundation.h>

/// Looks a key up in the table matching the device language, falling back to
/// English. Never return a raw key to the screen: a missing key is a build error,
/// caught by tools/check.py before it can reach a device.
NSString *SCILocalized(NSString *key);
