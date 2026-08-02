#import <Foundation/Foundation.h>

///
/// Asks YouTube for a video's formats, as a client that still gets file links.
///
/// This exists because of one line in a diagnostics report from a real device: every
/// stream the app was holding answered `-URL` with `?cpn=…` — a query fragment, not a
/// link. Four of the twelve formats were H.264, which iOS plays perfectly well, so the
/// codec was never the obstacle. The app simply is not given file URLs any more: YouTube
/// 21.30.5 streams through the piecewise server-driven protocol, where the player asks
/// for ranges rather than fetching a file.
///
/// So reading the app's own streaming data cannot work, and no amount of widening an
/// itag list changes that. What does work is asking YouTube directly, over its InnerTube
/// API, as one of the clients that is still served plain URLs — which is what every
/// working YouTube downloader does, and what a 25 MB reference tweak turned out to be
/// doing behind its bundled media library.
///
/// **The video id goes to YouTube.** That is worth stating plainly next to the care taken
/// elsewhere: SponsorBlock is asked by hash precisely so a third party cannot know what
/// is being watched. Here the recipient is YouTube itself, already streaming the video to
/// this device, on the same connection, for the video it is already playing. Nothing is
/// disclosed that was not disclosed a second earlier.
///
/// No signature deciphering, and that is not an oversight: the clients below are served
/// ready-to-fetch links, which is precisely why they are the ones used.
///
@interface SCIYTStreamAPI : NSObject

/// The `streamingData` object from a fresh player response, or nil.
///
/// Returned as parsed JSON rather than a model type: the caller already knows how to
/// read a dictionary of formats, and inventing a class for it would add a translation
/// step between two things that already agree.
+ (void)streamingDataForVideo:(NSString *)videoID
                   completion:(void (^)(NSDictionary *streamingData, NSString *failure))completion;

@end
