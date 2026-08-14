#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Which bundle identifiers the user asked CarPlay to bridge, shared by both halves
/// of the app-display feature: the SpringBoard-side admission spoof and the app-side
/// scene bridge each need the identical answer to "is this app on the list", read
/// from the identical preference -- SCICPBridgedAppsKey, in SCICPPrefsKeys.h -- so
/// the parsing lives once rather than twice.
///
BOOL SCICPBundleIsBridged(NSString *bundleID);

NS_ASSUME_NONNULL_END
