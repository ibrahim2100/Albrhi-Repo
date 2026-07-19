#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

///
/// Albrhi bilingual localization layer (Arabic / English)
///
/// Language resolution order:
///   1. User override stored in NSUserDefaults key "albrhi_language" ("ar" / "en" / "system")
///   2. Device preferred language (falls back to English for unsupported locales)
///
/// Usage: SCILocalized(@"hide_ads_title")
///

@interface SCILocalize : NSObject

/// Returns the localized string for the given key in the active language.
/// Falls back to the key itself if not found.
+ (NSString *)stringForKey:(NSString *)key;

/// Active language code: "ar" or "en".
+ (NSString *)activeLanguage;

/// Whether the active language is right-to-left (Arabic).
+ (BOOL)isRTL;

/// Sets the user language override. Pass "ar", "en", or "system".
+ (void)setLanguageOverride:(NSString *)code;

/// The current override value ("ar" / "en" / "system").
+ (NSString *)languageOverride;

@end

/// Convenience macro used throughout the UI.
#define SCILocalized(key) [SCILocalize stringForKey:(key)]
