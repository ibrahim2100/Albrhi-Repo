#import <Foundation/Foundation.h>

///
/// The formats the player is already holding, read out of the player response.
///
/// This is the source that was missed for seven releases, and the reason downloading
/// looked impossible.
///
/// The tweak was reading `MLStreamingData` — the media layer's own view of the streams,
/// whose `MLRemoteStream` objects answer `-URL` with `?cpn=…` because that layer fetches
/// byte ranges rather than files. That is a real dead end, and every probe of it came
/// back empty because there is genuinely nothing there.
///
/// But it is not the only streaming data in the app. `YTPlayerViewController` also holds
/// `-contentPlayerResponse`, and inside it the protobuf player response carries its own
/// `streamingData` with `adaptiveFormatsArray` — `YTIFormatStream` objects that do have a
/// `url`. Same video, same app, a different object graph, and nobody had looked at it.
///
/// Established from YouMod by Tonwalter888 (GPLv3, as this is), which reads both sources
/// and appends whatever each one yields. Every selector below was then checked against a
/// real 21.30.5 binary before it was written here — `-contentPlayerResponse` and
/// `-activeVideo` return objects, `-playerData` is implemented by `YTPlayerResponse`, and
/// `+[YTDataUtils generateClientSideNonce]` is on the metaclass where a class method
/// lives.
///
/// `adaptiveFormatsArray` has no static implementation anywhere in the binary, and that
/// is expected rather than alarming: every YTI* class is a GPBMessage, which resolves its
/// fields from a generated descriptor at runtime and therefore declares no methods and no
/// ivars at all.
///
/// Asking the player costs no network request, no borrowed client identity, and nothing
/// YouTube can revoke next week. It is tried before the InnerTube request for exactly
/// that reason.
///
@interface SCIYTPlayerStreams : NSObject

/// Remembered when a video activates, so the formats can be read later without going
/// looking for a controller. Weak: the player belongs to YouTube.
+ (void)rememberPlayer:(id)player;

/// The playback data handed to the same hook, which is where this should have been
/// reading from all along.
///
/// A trace from a device showed the captured controller alive but answering nil to
/// -contentPlayerResponse, -playerResponse and -activeVideo alike: YouTube builds a
/// player controller per surface, and the one that last announced a video has gone idle
/// by the time anyone holds the video down.
///
/// `withPlaybackData:` is the third argument of that hook and was being discarded.
/// YTPlaybackData carries -playerResponse and -CPN and nothing else worth mentioning —
/// it exists to hand exactly this over, at the moment it is true, with no searching and
/// no stale object in between.
+ (void)rememberPlaybackData:(id)playbackData;

/// The raw format objects the player is holding, or an empty array. Each is a
/// `YTIFormatStream`; the caller reads the fields it needs.
+ (NSArray *)formatObjects;

/// A link made fetchable: throttling parameter removed, playback nonce added if the URL
/// arrived without one.
+ (NSString *)preparedURLFrom:(NSString *)urlString;

/// What the last walk found at each step, for the report. Nil until one has run.
+ (NSString *)lastTrace;

/// The video's HLS playlist, or nil.
///
/// This is what downloading turns on. Every individual format on this build arrives
/// without an address -- measured through the media layer, the nested format, the player
/// response and four InnerTube clients -- but the playlist that lists them has one, and
/// a playlist is a list of ordinary segments.
///
/// It is also where every working tweak ends up: YTLite reads this exact field and hands
/// it to a bundled FFmpeg, nineteen of its twenty megabytes.
/// The playlist for one named video, from the capture filed under that id.
///
/// Shorts needs this and nothing else does. The unnamed version below returns whatever was
/// captured last, which during Shorts is the clip being preloaded rather than the one on
/// screen -- three releases went into trying to detect that instead of avoiding it.
+ (NSString *)hlsManifestURLForVideo:(NSString *)videoID;

/// Whether a playlist address really serves a given video.
///
/// The two are named differently -- an address uses the docid, which is the same eight bytes
/// the eleven-character id encodes -- so this converts before comparing. Verified against a
/// real pair from a device before being relied on, which 0.30.2 was not.
+ (BOOL)manifest:(NSString *)manifest isForVideo:(NSString *)videoID;

+ (NSString *)hlsManifestURL;

/// One field of a format object, by selector or by key.
///
/// Exposed rather than kept private because a GPBMessage answers -respondsToSelector:
/// with NO for fields KVC reads without complaint, and every caller that reads one of
/// these objects needs that same both-ways lookup. Two copies of it would drift.
+ (id)valueOf:(NSString *)name on:(id)object;
+ (NSString *)stringOf:(NSString *)name on:(id)object;

@end
