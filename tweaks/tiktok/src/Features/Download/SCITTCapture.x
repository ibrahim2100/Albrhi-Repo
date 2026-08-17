#import "SCITTCapture.h"
#import "SCITTMedia.h"
#import "../../Prefs.h"
#import "../../SCILog.h"

///
/// The download link comes from `AWEVideoModel`, caught at its own construction.
///
/// **Every earlier attempt went through the aweme model, and a device report finally
/// explained why that could not work.** `AWEAwemeModel -video` answers nil for the
/// overwhelming majority of models at the moment they are built, and a retry timer
/// only partly papered over it. Meanwhile the one path that *did* keep resolving --
/// `-URLList` on the aweme model, 288 times out of 706 -- turned out to be the
/// **sound's** URL list: the file it produced was 972 KB of `audio/mp4` with no video
/// track at all, which is why every save reported "sound saved". A confident wrong
/// answer, which is worse than no answer.
///
/// `AWEVideoModel` itself is confirmed real by that same report family -- one of them
/// said `"AWEVideoModel has no -playAddr"`, which only a real class can say, and
/// another said `video.playURL` ended `"at AWEURLModel"`, one hop short of that class's
/// own doubly-confirmed `-bestURLtoDownload`. Hooking the video model's construction
/// removes the wait entirely: by the time this object exists, its own play URL is what
/// it was built to carry.
///
/// `%orig` runs first in both hooks and the return value is never altered -- this
/// reads, it does not filter. Nothing here can drop a video the way the ad filter
/// deliberately does.
///

@interface AWEVideoModel : NSObject
@end

%group Capture

%hook AWEVideoModel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    id built = %orig;
    if (built && SCIPrefEnabled(SCIPrefDownloadButton)) {
        [SCITTMedia captureVideoModel:built];
    }
    return built;
}

- (instancetype)init {
    id built = %orig;
    if (built && SCIPrefEnabled(SCIPrefDownloadButton)) {
        [SCITTMedia captureVideoModel:built];
    }
    return built;
}

%end

%end


void SCITTInstallCapture(void) {
    if (!NSClassFromString(@"AWEVideoModel")) {
        SCILogV(@"AWEVideoModel is not in this build — no video-model capture");
        return;
    }

    %init(Capture);
    SCILogV(@"video-model capture attached to AWEVideoModel");
}
