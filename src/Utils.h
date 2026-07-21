#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>
#import <os/log.h>
#import <objc/message.h>

#import "../modules/JGProgressHUD/JGProgressHUD.h"

#import "InstagramHeaders.h"
#import "QuickLook.h"

#import "Localization/SCILocalize.h"
#import "Settings/SCISettingsViewController.h"

/// Gated logging. Silent unless the user turns on verbose logging in Debug, so a
/// release build doesn't narrate itself into the system log.
#define SCILogV(fmt, ...)     do {         if ([[NSUserDefaults standardUserDefaults] boolForKey:@"verbose_logging"]) {             NSLog((fmt), ##__VA_ARGS__);         }     } while (0)

#define SCILog(fmt, ...) \
    do { \
        NSString *tmpStr = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
        os_log(OS_LOG_DEFAULT, "[SCInsta Test] %{public}s", tmpStr.UTF8String); \
    } while(0)

#define SCILogId(prefix, obj) os_log(OS_LOG_DEFAULT, "[SCInsta Test] %{public}@: %{public}@", prefix, obj);

@interface SCIUtils : NSObject

+ (BOOL)getBoolPref:(NSString *)key;
+ (double)getDoublePref:(NSString *)key;
+ (NSString *)getStringPref:(NSString *)key;

+ (void)cleanCache;

// Displaying View Controllers
+ (void)showQuickLookVC:(NSArray<id> *)items;
+ (void)showShareVC:(id)item;
+ (void)showSettingsVC:(UIWindow *)window;

// Colours
+ (UIColor *)SCIColor_Primary;
+ (UIColor *)colorFromHexString:(NSString *)hex;
+ (NSString *)hexStringFromColor:(UIColor *)color;
+ (void)showAccentColorPicker;
+ (void)resetAccentColor;

// Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc;
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode;

+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc;
+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc dismissAfterDelay:(CGFloat)dismissDelay;
+ (JGProgressHUD *)showSuccessHUDWithDescription:(NSString *)desc;
+ (void)copyAccountInfoForUser:(id)user;
/// Localized "Follows you" / "Doesn't follow you" for a given IGUser, or nil when
/// the relationship can't be determined (e.g. your own profile).
+ (NSString *)followStatusStringForUser:(id)user;
/// Username of the currently logged-in account, or nil. Used to avoid showing a
/// follow-back badge on your own profile.
+ (NSString *)currentUsername;

// Media
+ (NSURL *)getPhotoUrl:(IGPhoto *)photo;
+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media;

+ (NSURL *)getVideoUrl:(IGVideo *)video;
+ (NSURL *)getVideoUrlForMedia:(id)media;
+ (NSURL *)getAudioUrlForMedia:(id)mediaLike;
+ (NSArray<NSDictionary *> *)availableVideoQualitiesForVideo:(IGVideo *)video;

// Quality-selection helpers (IGAPIVideoVersion objects or dictionaries)
+ (long long)qualityValueFrom:(id)version key:(NSString *)key;
+ (NSString *)urlStringFromVersion:(id)version;
+ (NSURL *)bestURLFromVersions:(id)versions;

// View Controllers
+ (UIViewController *)viewControllerForView:(UIView *)view;
+ (UIViewController *)viewControllerForAncestralView:(UIView *)view;
+ (UIViewController *)nearestViewControllerForView:(UIView *)view;

// Functions
+ (NSString *)IGVersionString;
+ (BOOL)isNotch;

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view;

// Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title;
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title;
+ (BOOL)showConfirmation:(void(^)(void))okHandler;
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler;
+ (void)showRestartConfirmation;

// Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title;
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle;

// Math
+ (NSUInteger)decimalPlacesInDouble:(double)value;

// Ivars
+ (id)getIvarForObj:(id)obj name:(const char *)name;
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value;

@end
