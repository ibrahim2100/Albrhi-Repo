#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

///
/// Every YouTube class this tweak touches.
///
/// Each one below was checked against the class list of a real YouTube 21.30.5
/// binary before being written here, and the selectors against that class's own
/// method list -- class methods against the metaclass, which is where a +factory
/// actually lives and where a naive dump does not look.
///
/// That is not ceremony. The tweak this project studied to find these hook points
/// targets five classes that do not exist in the build it ships for
/// (YTAutonavController, YTCaptionController, YTHeaderLogoView,
/// YTInlinePlayerViewController, MLVideoView), so those features are dead for its
/// users with nothing to say so. A class name copied from another project is a
/// lead, never a fact.
///

// MARK: - Settings

/// One row in YouTube's own settings. The factories are class methods; the exact
/// signatures below are the ones present in 21.30.5, of nineteen that exist.
@interface YTSettingsSectionItem : NSObject
+ (instancetype)itemWithTitle:(NSString *)title
             titleDescription:(NSString *)titleDescription
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              detailTextBlock:(id)detailTextBlock
                  selectBlock:(BOOL (^)(id cell))selectBlock;

+ (instancetype)switchItemWithTitle:(NSString *)title
                   titleDescription:(NSString *)titleDescription
            accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           switchOn:(BOOL)switchOn
                        switchBlock:(BOOL (^)(id cell, BOOL value))switchBlock
                      settingItemId:(NSInteger)settingItemId;
@end

/// The settings screen itself. setSectionItems:... is how a section's contents are
/// handed over, and is the one call that makes a custom category appear.
@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSArray *)sectionItems
            forCategory:(NSInteger)category
                  title:(NSString *)title
                   icon:(id)icon
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
- (void)reloadData;
@end

/// Builds each section on demand. Hooking updateSectionForCategory:withEntry: is
/// what lets a category we invented be answered rather than ignored.
@interface YTSettingsSectionItemManager : NSObject
@property (nonatomic, weak) YTSettingsViewController *settingsViewControllerDelegate;
- (void)updateSectionForCategory:(NSInteger)category withEntry:(id)entry;
@end

/// Owns the order categories appear in. Appending to +settingsCategoryOrder is what
/// puts our row on the list at all.
@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

// MARK: - Playback

/// A protobuf message -- every YTI* class here descends from GPBMessage, which is
/// why none of them declares a single property below. GPBMessage resolves its
/// fields from a generated descriptor at runtime, so the class carries no static
/// methods and no ivars at all.
///
/// The consequence is the useful part: -description prints the entire message tree
/// as text. That is how this tweak reports what YouTube said about a video instead
/// of guessing which of three possible stream paths is live on a given build.
@interface GPBMessage : NSObject
@end

@interface YTIPlayerResponse : GPBMessage
@end

@interface YTIStreamingData : GPBMessage
@end

/// The media layer's video object, carrying the streaming data the player is
/// actually using -- as opposed to what the response merely offered.
@interface MLVideo : NSObject
@property (nonatomic, readonly) NSString *ID;
- (id)streamingData;
- (id)videoDetails;
@end

/// Wraps the player overlay and is handed the response for each video. Chosen as
/// the capture point because it receives the whole YTIPlayerResponse, not just the
/// streams: the video details and the playability status matter to the report too.
@interface YTPlayerOverlayWrapper : NSObject
- (void)setPlayerResponse:(YTIPlayerResponse *)playerResponse;
@end
