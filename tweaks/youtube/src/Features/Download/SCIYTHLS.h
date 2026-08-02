#import <Foundation/Foundation.h>

///
/// One quality in an HLS playlist.
///
@interface SCIHLSVariant : NSObject
@property (nonatomic, copy) NSString *playlistURL;
@property (nonatomic, copy) NSString *codecs;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) long long bandwidth;

/// "1080p · H.264", for the quality sheet.
- (NSString *)label;
@end


///
/// Saving a video from its HLS playlist.
///
/// This is the route, and it took nine releases of measurement to be sure of it. Every
/// individual format on this build arrives without an address — established through the
/// media layer, the format nested inside it, the player response, and four InnerTube
/// client identities. What does have an address is the *playlist*: YouTube hands the app
/// an `hls_variant` manifest, and a manifest is a list of ordinary segments.
///
/// It is also where every tweak whose downloading works ends up. YTLite reads that one
/// field and gives it to a bundled FFmpeg; DLEasy, Reborn and YTKACE each carry the same
/// library for the same reason.
///
/// **This does not carry FFmpeg**, and whether that holds depends on something only the
/// playlist can say. If its segments are fragmented MP4 — an `#EXT-X-MAP` line and `.m4s`
/// parts — then joining them end to end produces a file AVFoundation reads directly, and
/// the export is a passthrough copy. If they are MPEG-TS instead, that does not work and
/// the report will say so rather than leaving a broken file behind.
///
/// Segments are appended to a file as they arrive rather than gathered in memory: a
/// 1080p video runs to a couple of hundred megabytes and holding that twice over is not
/// something to do on a phone.
///
@interface SCIYTHLS : NSObject

/// Reads the master playlist and returns the qualities worth offering, best first.
/// Anything iOS cannot play is filtered out here rather than after it is chosen.
+ (void)variantsForManifest:(NSString *)manifestURL
                 completion:(void (^)(NSArray<SCIHLSVariant *> *variants, NSString *failure))completion;

/// Downloads one quality and hands back a finished .mp4, or a sentence saying why not.
/// `progress` is called on the main queue with a fraction between 0 and 1.
+ (void)downloadVariant:(SCIHLSVariant *)variant
               progress:(void (^)(double fraction))progress
             completion:(void (^)(NSURL *file, NSString *failure))completion;

@end
