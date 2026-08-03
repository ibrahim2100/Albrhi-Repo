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

/// Builds each section on demand.
///
/// The property that used to be declared here is gone, and it is the reason 0.1.1
/// crashed. `_settingsViewControllerDelegate` is an **ivar with no getter**: it is set
/// once through
/// -initWithParentResponder:controllerDelegate:dataDelegate:settingsViewControllerDelegate:
/// and never exposed. Declaring it as a property made `self.settingsViewControllerDelegate`
/// compile, which was never the question -- at runtime it was an unrecognised selector,
/// went to message forwarding, and took the app down the moment Settings opened.
///
/// The crash report named this exactly: our own dylib, then _CF_forwarding_prep_0, then
/// the exception. Reaching that ivar again means object_getIvar or KVC, not a property
/// invented in a header.
@interface YTSettingsSectionItemManager : NSObject
- (void)updateSectionForCategory:(NSInteger)category withEntry:(id)entry;
@end

/// Declares a category order — and in 21.30.5 the settings screen does not read it.
///
/// This is the mistake this project's own notes warn about, made again: the selector
/// is in the binary, so it looks like the way in, and appending to it puts a category
/// on a list nobody consults. The row simply never appeared. Kept hooked because it
/// costs nothing and older builds may still use it, but it is not what makes the
/// section show up.
@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

/// What the settings screen actually reads. Categories live inside groups, and a
/// category in no group is a category on no screen.
@interface YTAppSettingsGroupPresentationData : NSObject
+ (NSArray *)orderedGroups;
@end

/// One group of categories — "Account", "Video and audio", and so on.
///
/// -type is an unsigned enum whose values are not readable from the binary, so
/// nothing here guesses at them: the group to extend is identified by position in
/// +orderedGroups and matched afterwards by the type it turned out to have.
@interface YTSettingsGroupData : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) unsigned long long type;
- (NSArray *)orderedCategories;
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

// MARK: - Ads and playback
//
// Everything below is the *model and service* layer, and that is a decision rather
// than a coincidence.
//
// Two reference tweaks were measured against this binary. The one that hooks view
// classes has nineteen target names that are not classes in 21.30.5 at all -- so
// those features are dead for its users with nothing to say so. The one that hooks
// models and services, 68 KB doing only this, has **zero** dead selectors and
// thirteen of its fifteen classes alive. Views get renamed and rewritten in Swift
// between releases; a player response does not.
//
// Every selector below was checked against the class that actually implements it,
// class methods against the metaclass, where a naive dump does not look.

/// Adds ad capability and targeting to the InnerTube request context. Emptied, the
/// server is never told this client wants ads -- so they are not sent, rather than
/// sent and then hidden.
@interface YTAdsInnerTubeContextDecorator : NSObject
- (void)decorateContext:(id)context;
@end

@interface YTAccountScopedAdsInnerTubeContextDecorator : NSObject
- (void)decorateContext:(id)context;
@end

/// The anti-adblock fingerprint. Class methods, so they live on the metaclass.
@interface YTAdShieldUtils : NSObject
+ (NSDictionary *)spamSignalsDictionary;
+ (NSDictionary *)spamSignalsDictionaryWithoutIDFA;
@end

/// Where in-player ads are decided: pre-roll, mid-roll, and the kind the server
/// stitches into the stream itself.
@interface YTIPlayerResponse (SCIAds)
- (BOOL)isMonetized;
- (id)adIntroRenderer;
- (BOOL)hasAdLoggingData;
- (BOOL)isCuepointAdsEnabled;
- (BOOL)isDAIEnabledPlayback;
- (id)paidContentOverlayElementRendererOptions;
@end

/// Builds the coordinator that plays ads. No coordinator, no ad playback.
@interface YTLocalPlaybackController : NSObject
- (id)createAdsPlaybackCoordinator;
@end

/// Whether the server says this video may keep playing with the screen off. The gate
/// for background playback, and it sits on the response rather than on any view.
@interface YTIPlayabilityStatus : GPBMessage
- (BOOL)isPlayableInBackground;
@end

/// The same question, asked again by the playback layer rather than the response.
/// Both implement it, both are asked at different moments, and forcing one while
/// leaving the other gives playback that stops depending on which path the app took.
@interface YTPlaybackData : NSObject
- (BOOL)isPlayableInBackground;
@end

/// Owns the "please update" dialog, among much else.
@interface YTGlobalConfig : NSObject
- (BOOL)shouldBlockUpgradeDialog;
@end

/// The player, and the one class that owns every piece SponsorBlock needs: it is told
/// when a video activates, it is told when the time moves, and it can seek.
///
/// The signatures below are the type encodings read out of the binary, not inferred:
///   currentVideoMediaTime                                    d16@0:8
///   seekToTime:                                              v24@0:8d16
///   playbackController:didActivateVideo:withPlaybackData:    v40@0:8@16@24@32
///   potentiallyMutatedSingleVideo:currentVideoTimeDidChange: v32@0:8@16@24
///
/// So the time is a double and both delegate arguments are objects. Getting that wrong
/// in a Logos hook does not fail to compile -- it passes garbage.
///
/// Note what is *not* declared: -singleVideo:currentVideoTimeDidChange:. Other classes
/// implement it, this one does not, and the reference tweak hooks it here anyway --
/// adding a method that is never called.
@interface YTPlayerViewController : UIViewController
- (double)currentVideoMediaTime;
- (void)seekToTime:(double)time;

/// Both verified present on 21.30.5. -pause is how our own player stops this one: two
/// players inside one process are not arbitrated by the audio session, so one has to be
/// told, and without that both played at once.
- (void)pause;
- (void)play;

/// The two below are *leads*, taken from iSponsorBlock, which is tested on this same
/// 21.x line and reads both off this class. They are declared so the code compiles and
/// called only behind -respondsToSelector:, because a lead that is wrong here is an
/// unrecognised selector, which is how 0.1.1 died.
///
/// -currentVideoID matters because it is a second way to learn the video: 0.3.0 asked
/// only the video object, under names it does not answer to, and skipped nothing at all.
/// Asking two objects means one renamed accessor no longer takes the feature down.
- (NSString *)currentVideoID;
- (double)currentVideoTotalMediaTime;
@end

/// The feed. Sections arrive here as renderers, which is where a promoted one can be
/// dropped by the identifier the server itself attached to it.
@interface YTInnerTubeCollectionViewController : UIViewController
- (void)addSectionsFromArray:(NSArray *)sections;
@end

// MARK: - The progress bar
//
// The one place this tweak hooks views, and it is done knowingly.
//
// Everything else here is model or service layer precisely because view classes get
// renamed between releases. These three cannot be: a marker has to be drawn *on* the
// bar, and the bar is a view. So the risk is accepted and then contained --
//
//   * all three are hooked, because which one a build renders is not knowable from
//     the binary, and a %hook on a class that does not exist simply never attaches;
//   * only -layoutSubviews is touched, which every UIView has;
//   * the markers are laid out with frames, never constraints. The layout engine took
//     this tweak down in 0.1.1 and again in 0.1.3, and a rectangle needs no help from it;
//   * the diagnostics page reports which of the three was found, so "no colours" is
//     answerable from the phone instead of by guessing.
//
// The names are from iSponsorBlock, which is tested on this same 21.x line. Leads, as
// ever, not facts -- which is why the report says which one actually turned up.

@interface YTInlinePlayerBarView : UIView
/// Guarded by -respondsToSelector: at every call site; the fallback is the duration
/// captured from the player controller.
- (double)totalTime;
@end

@interface YTSegmentableInlinePlayerBarView : YTInlinePlayerBarView
@end

@interface YTModularPlayerBarView : UIView
- (double)totalTime;
@end

//
// Quality. Both are model-layer, which is the layer this project prefers to hook: a
// format list and a constraint object are not views and do not get renamed for a redesign.
//
// The constraint is typed `id` on purpose. What goes in it is an
// MLResolutionCappedFormatConstraint built at runtime, and naming that class in a header
// would make this file fail to compile on a build that dropped it, for no gain -- nothing
// here calls anything on the object, it is only handed back.
//

@interface MLHAMPlayerItem : NSObject
@property (nonatomic, strong) id videoFormatConstraint;
@end

//
// The like/dislike counter node.
//
// An ASDisplayNode, so the UIView only exists after -didLoad and -view is the way to it.
// Declared because the hook reads that view; nothing else here is touched.
//
@interface YTRollingNumberNode : NSObject
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, strong) id element;
@end
