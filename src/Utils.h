#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>
#import <os/log.h>
#import <objc/message.h>

#import "../modules/JGProgressHUD/JGProgressHUD.h"

#import "SCILog.h"
#import "InstagramHeaders.h"
#import "QuickLook.h"

#import "Localization/SCILocalize.h"
#import "Settings/SCISettingsViewController.h"

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

/// The raw DASH manifest XML for a video, or nil when this build exposes none.
///
/// Instagram serves video over DASH, and the manifest lists renditions that
/// -videoVersions does not carry. Nothing parses this yet: the point is to read
/// what Instagram actually sends on a real device before writing a parser
/// against a guessed schema.
+ (nullable NSString *)dashManifestXMLForVideo:(nullable id)video media:(nullable id)media;

/// Every zero-argument selector on an object's class hierarchy whose name
/// contains @c needle, case-insensitively.
///
/// The first version of the DASH probe guessed four selector names and found
/// none of them, which is the mistake this project keeps paying for: a name
/// that exists in a class dump is not a name the object answers to. Asking the
/// runtime what the object actually responds to replaces the guess with a fact.
+ (NSArray<NSString *> *)selectorsMatching:(NSString *)needle onObject:(nullable id)object;

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
