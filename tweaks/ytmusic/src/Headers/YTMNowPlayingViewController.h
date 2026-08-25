//
//  YTMNowPlayingViewController.h
//  Albrhi for YouTube Music
//
//  **Its own header, and that is not tidiness.** SelectableLyrics.x declares this class again with
//  its own added properties -- which is how a carried-over file adds state to a hooked class -- and
//  two @interface blocks for one class in a single translation unit is a compile error, not a
//  merge. So the base declaration lives here, imported only by the files that need it and not by
//  the shared header everything pulls in.
//
#import "YTMUpstream.h"

@interface YTMNowPlayingViewController : UIViewController
- (void)didTapNextButton;
- (void)didTapPrevButton;
- (void)didTapSeekForwardButton;
- (void)didTapSeekBackwardButton;
- (void)longPressPrev:(UILongPressGestureRecognizer *)gesture;
- (void)longPressNext:(UILongPressGestureRecognizer *)gesture;
@end
