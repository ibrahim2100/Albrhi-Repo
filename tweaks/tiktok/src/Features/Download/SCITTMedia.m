#import "SCITTMedia.h"
#import "../../TikTokHeaders.h"
#import "../../SCILog.h"
#import <objc/message.h>

@implementation SCITTMediaItem
@end


static NSMutableArray<SCITTMediaItem *> *sciRecent = nil;
static NSUInteger const kSCIMediaCap = 30;
static NSString *sciLastAttemptState = nil;

@implementation SCITTMedia

/// A value however TikTok's own accessor hands it back, turned into a URL without
/// assuming which shape it is -- `AWEURLModel -bestURLtoDownload` is confirmed to
/// exist and to be called by two reference tweaks; what type it actually returns on
/// this build is not, so both plausible shapes are read rather than one being trusted.
static NSURL *SCITTURLFromValue(id value) {
    if (!value) return nil;
    if ([value isKindOfClass:[NSURL class]]) return value;
    if ([value isKindOfClass:[NSString class]]) return [NSURL URLWithString:value];
    return nil;
}

+ (void)captureModel:(AWEAwemeModel *)model {
    if (!model) return;

    @try {
        if (![model respondsToSelector:@selector(isAds)]) {
            // Not fatal to capture -- only relevant to the ad filter, which already
            // checked this before deciding to keep the model at all.
        }

        if (![model respondsToSelector:NSSelectorFromString(@"videoModel")]) {
            sciLastAttemptState = @"model has no -videoModel";
            return;
        }
        id video = ((id (*)(id, SEL))objc_msgSend)(model, NSSelectorFromString(@"videoModel"));
        if (!video) {
            sciLastAttemptState = @"-videoModel answered nil";
            return;
        }

        if (![video respondsToSelector:NSSelectorFromString(@"playAddr")]) {
            sciLastAttemptState = [NSString stringWithFormat:
                @"%@ has no -playAddr", NSStringFromClass([video class])];
            return;
        }
        id playAddr = ((id (*)(id, SEL))objc_msgSend)(video, NSSelectorFromString(@"playAddr"));
        if (!playAddr) {
            sciLastAttemptState = @"-playAddr answered nil";
            return;
        }

        if (![playAddr respondsToSelector:@selector(bestURLtoDownload)]) {
            sciLastAttemptState = [NSString stringWithFormat:
                @"%@ has no -bestURLtoDownload", NSStringFromClass([playAddr class])];
            return;
        }
        id resolved = [playAddr bestURLtoDownload];
        NSURL *url = SCITTURLFromValue(resolved);
        if (!url) {
            sciLastAttemptState = [NSString stringWithFormat:
                @"-bestURLtoDownload answered %@, not a URL or string",
                resolved ? NSStringFromClass([resolved class]) : @"nil"];
            return;
        }

        sciLastAttemptState = @"resolved a download URL";

        if (!sciRecent) sciRecent = [NSMutableArray array];

        // Same video seen twice -- a recycled cell rebound, a scroll back up -- moves
        // to the front rather than duplicating.
        for (SCITTMediaItem *existing in [sciRecent copy]) {
            if ([existing.url isEqual:url]) [sciRecent removeObject:existing];
        }

        SCITTMediaItem *item = [[SCITTMediaItem alloc] init];
        item.url = url;
        item.seen = [NSDate date];
        [sciRecent insertObject:item atIndex:0];

        while (sciRecent.count > kSCIMediaCap) [sciRecent removeLastObject];
    } @catch (NSException *exception) {
        // A capture is a convenience; TikTok's own feed is not. Anything thrown here
        // costs this one row, never the app.
        sciLastAttemptState = [NSString stringWithFormat:@"threw: %@", exception.reason ?: @"?"];
        SCILogV(@"media capture: %@", exception.reason);
    }
}

+ (NSArray<SCITTMediaItem *> *)recent {
    return [sciRecent copy] ?: @[];
}

+ (void)forgetAll {
    [sciRecent removeAllObjects];
}

+ (NSString *)lastAttemptState {
    return sciLastAttemptState ?: @"nothing captured yet";
}

@end
