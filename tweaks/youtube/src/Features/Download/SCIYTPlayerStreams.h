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

/// The raw format objects the player is holding, or an empty array. Each is a
/// `YTIFormatStream`; the caller reads the fields it needs.
+ (NSArray *)formatObjects;

/// A link made fetchable: throttling parameter removed, playback nonce added if the URL
/// arrived without one.
+ (NSString *)preparedURLFrom:(NSString *)urlString;

/// One field of a format object, by selector or by key.
///
/// Exposed rather than kept private because a GPBMessage answers -respondsToSelector:
/// with NO for fields KVC reads without complaint, and every caller that reads one of
/// these objects needs that same both-ways lookup. Two copies of it would drift.
+ (id)valueOf:(NSString *)name on:(id)object;
+ (NSString *)stringOf:(NSString *)name on:(id)object;

@end
