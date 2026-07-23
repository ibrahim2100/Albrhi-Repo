#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Tells the user when a newer Albrhi has been released.
///
/// The only thing this sends is an HTTP GET to GitHub's public releases endpoint —
/// no account, no usage, no identifier, nothing about the user or their device. It
/// is still a request the tweak makes on its own, which is why it can be turned
/// off, and why the setting says plainly what it contacts.
///
/// Where the user is sent depends on how Albrhi was installed: a jailbroken copy
/// updates through Sileo, while a sideloaded one has to fetch the new dylib. Both
/// are detected at runtime, since a single build serves both.
///
@interface SCIUpdateChecker : NSObject

/// Runs at launch, at most once a day, and shows a banner only if there is a newer
/// version. Silent about everything else — failures included, since a user who did
/// not ask for a check should not be told one failed.
+ (void)checkQuietly;

/// The "check for updates" button. Always reports something, including "you are up
/// to date" and any error, because here the user asked.
///
/// @c presenter may be nil — a settings row has no view controller to hand — in
/// which case whatever is frontmost presents the result.
+ (void)checkFromSettings:(nullable UIViewController *)presenter;

/// YES when this copy was installed as a jailbreak package rather than sideloaded.
+ (BOOL)isJailbrokenInstall;

@end

NS_ASSUME_NONNULL_END
