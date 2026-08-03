#import <UIKit/UIKit.h>
#import "SCIYTHostPlayer.h"
#import "../../../SCILog.h"
#import "../../../YouTubeHeaders.h"

///
/// Stopping YouTube's own player when ours starts.
///
/// Two videos played at once, and the reason is that both are in the same process. An audio
/// session only arbitrates between *apps*: taking it, activating it, even deactivating it
/// with NotifyOthersOnDeactivation, says nothing to another player living inside the same
/// one. There is no setting for this. The other player has to be told, by name.
///
/// It also explains the second half of the complaint -- locking the phone stopping the
/// sound. With two players running, whichever one YouTube's own background handling decided
/// to act on was not necessarily ours, and it stops what it thinks is finished.
///
/// The reference is weak and recorded when a player actually plays rather than when one is
/// built. YouTube makes player controllers for things it is only preloading, and pausing one
/// of those would be pausing nothing while the real one carried on.
///

static __weak YTPlayerViewController *sciHostPlayer = nil;

@implementation SCIYTHostPlayer

+ (void)pauseHost {
    YTPlayerViewController *player = sciHostPlayer;
    if (!player) return;

    // Guarded even though -pause is present on this build: this is the one call in the
    // tweak that reaches into YouTube's playback while our own screen is opening, and a
    // selector that went missing should cost the courtesy, not the player.
    if (![player respondsToSelector:@selector(pause)]) {
        SCILogV(@"host: no -pause on %@", NSStringFromClass([player class]));
        return;
    }

    [player pause];
    SCILogV(@"host: paused YouTube's player");
}

+ (BOOL)isHostKnown { return sciHostPlayer != nil; }

@end


%hook YTPlayerViewController

- (void)play {
    %orig;

    // Recorded on play, not on creation. See above: preloaded controllers are built and
    // never started, and remembering one of those means pausing something nobody is
    // watching while the real player keeps going.
    sciHostPlayer = self;
}

%end
