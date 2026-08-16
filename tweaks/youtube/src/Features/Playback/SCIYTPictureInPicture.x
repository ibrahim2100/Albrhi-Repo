#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"

///
/// Real, system Picture-in-Picture -- the same window iOS gives Safari a video for --
/// rather than anything this tweak draws itself.
///
/// The app already carries the whole thing: `AVPictureInPictureController` is linked, and
/// `MLVideo` answers `-isPlayableInPictureInPicture` and `-isPlayableInPictureInPictureByUser
/// Settings` right next to `-playableInBackground`, the same class and the same shape
/// SCIYTBackground.x already hooks. What gates it is the second one -- "by user settings" --
/// which is how the app tells its own PIP controller that this account's plan allows it.
/// Forcing it YES is the entire feature; the controller, the AVFoundation session and the
/// system window are all already there and already working, unlocked rather than built.
///
/// `-isPlayableInPictureInPicture` is left alone. It answers a different, narrower
/// question -- whether *this video* supports PIP at all, which can be genuinely NO for a
/// live stream or a restricted upload -- and forcing that one risks a PIP window opened on
/// a video that cannot actually play in it. Only the account-plan gate is forced.
///
%hook MLVideo

- (BOOL)isPlayableInPictureInPictureByUserSettings {
    if (!SCIPrefEnabled(SCIPrefNativePIP)) {
        return %orig;
    }
    return YES;
}

%end
