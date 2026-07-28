#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The optional "which quality?" sheet.
///
/// A picker was attempted three times and each one showed a single option. The
/// diagnostics finally said why: Instagram's DASH ladder for a reel is AV1 top to
/// bottom — eight renditions, none of them in a codec iOS will save — so a picker
/// asking "what can be saved" was correctly answered "one thing", the progressive
/// fallback. The qualities were always there; they were just all behind the
/// transcoder.
///
/// So this sits on the transcode path, not the download path, and lists the rungs
/// of the AV1 ladder. Off by default: taking the best available automatically is the
/// point of the tweak, and this only exists for the times when 2K is more than you
/// wanted to spend on battery, time and storage.
///
@interface SCIQualitySheet : NSObject

/// @param options  distinct AV1 renditions, tallest first.
/// @param chosen   run with the picked height.
+ (void)presentWithOptions:(NSArray<NSDictionary *> *)options
                    chosen:(void (^)(long long height))chosen;

@end

NS_ASSUME_NONNULL_END
