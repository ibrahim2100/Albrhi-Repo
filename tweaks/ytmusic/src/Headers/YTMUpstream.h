//
//  YTMUpstream.h
//  Albrhi for YouTube Music
//
//  The YouTube Music interfaces the carried-over hooks need, and nothing more.
//
//  **A subset, not a copy of upstream's 48 headers.** YTMEnhanced and YTMusicUltimate declare
//  every class they have ever touched; carrying all of them would mean this tweak's header
//  describing surfaces it does not hook, which is the same trap as a class dump read as a
//  manifest -- a name that exists is not a name this build sends.
//
//  Declared from YTMEnhanced (github.com/py233/YTMEnhanced), GPLv3, itself derived from
//  YTMusicUltimate. Attribution ships in control, CHANGELOG.md and the package notice.
//

#import <UIKit/UIKit.h>

@interface YTAssetLoader : NSObject
- (instancetype)initWithBundle:(NSBundle *)bundle;
- (UIImage *)imageNamed:(NSString *)image;
@end

@interface YTMPlaybackRateButtonHolder : NSObject
@property (readonly, copy, nonatomic) UIButton *button;
@end

@interface YTMPlayerControlsView : UIView
@property (readonly, nonatomic) NSArray<YTMPlaybackRateButtonHolder *> *playbackRateButtons;
@property (nonatomic, assign, readonly) UIButton *prevButton;
@property (nonatomic, assign, readonly) UIButton *nextButton;
@end

@interface YTMNowPlayingView : UIView
@property (nonatomic, assign, readonly) YTMPlayerControlsView *playerControlsView;
@end

@interface GOOHUDMessageAction : NSObject
@property (nonatomic, copy) NSString *title;
- (void)setHandler:(void (^)(void))handler;
@end

@interface YTMToastController : NSObject
- (void)showMessage:(NSString *)message
    HUDMessageAction:(GOOHUDMessageAction *)action
            infoType:(int)infoType
            duration:(CGFloat)duration;
@end

@interface YTPlayerViewController : UIViewController
@property (readonly, nonatomic) NSString *contentVideoID;
@property (nonatomic, assign, readonly) CGFloat currentVideoTotalMediaTime;
@property (nonatomic, strong) NSMutableDictionary *sponsorBlockValues;
- (void)seekToTime:(CGFloat)time;
- (NSString *)currentVideoID;
- (CGFloat)currentVideoMediaTime;
- (void)skipSegment;
@end

@interface QTMButton : UIButton
@property (nonatomic, copy, readwrite) NSString *accessibilityIdentifier;
@end

@interface YTMNavigationBarView : UIView
@end
