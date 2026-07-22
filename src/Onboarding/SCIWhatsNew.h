#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// One row on the welcome / what's-new screen.
@interface SCIWhatsNewItem : NSObject

@property (nonatomic, copy, readonly) NSString *symbolName;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *detail;
@property (nonatomic, strong, readonly, nullable) UIColor *tint;

+ (instancetype)itemWithSymbol:(NSString *)symbolName
                         title:(NSString *)title
                        detail:(NSString *)detail
                          tint:(nullable UIColor *)tint;

@end

///
/// Welcome and what's-new content.
///
/// Kept apart from the view controller so shipping a new release means editing a
/// list here, not touching layout code. `+shouldPresent` owns the "has this user
/// seen this version" decision, and nothing else needs to know how that's stored.
///

@interface SCIWhatsNew : NSObject

/// Whether the screen is due — first install, or the first launch after an update.
+ (BOOL)shouldPresent;

/// True when the user has never run Albrhi before, which changes the copy from
/// "what changed" to "welcome".
+ (BOOL)isFirstInstall;

/// Marks the current version as seen. Called when the sheet is dismissed.
+ (void)markCurrentVersionSeen;

+ (NSString *)headlineForFirstInstall:(BOOL)firstInstall;
+ (NSString *)subheadlineForFirstInstall:(BOOL)firstInstall;
+ (NSArray<SCIWhatsNewItem *> *)itemsForFirstInstall:(BOOL)firstInstall;

/// Intro screen — shown once, on first install, *before* the what's-new page. It
/// answers "what is this and how do I open the settings" rather than "what changed".
+ (NSString *)introHeadline;
+ (NSString *)introSubheadline;
+ (NSArray<SCIWhatsNewItem *> *)introItems;

/// The small print under the button. Where the joke lives.
+ (NSString *)footnoteForFirstInstall:(BOOL)firstInstall;

@end

NS_ASSUME_NONNULL_END
