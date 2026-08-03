#import "SCIYTDislikes.h"
#import "../../SCILog.h"

NSNotificationName const SCIYTDislikesDidArriveNotification = @"SCIYTDislikesDidArrive";

/// Counts already known, by video id.
static NSMutableDictionary<NSString *, NSString *> *sciCounts = nil;

/// Ids currently being asked about, so a layout pass that runs forty times does not start
/// forty requests for the same video.
static NSMutableSet<NSString *> *sciInFlight = nil;

/// Ids that came back with nothing. Kept so a video the archive does not have is asked
/// about once rather than on every redraw for as long as it is on screen.
static NSMutableSet<NSString *> *sciMissing = nil;

static NSString *sciLastState = nil;

@implementation SCIYTDislikes

+ (void)initialize {
    if (self != [SCIYTDislikes class]) return;
    sciCounts = [NSMutableDictionary dictionary];
    sciInFlight = [NSMutableSet set];
    sciMissing = [NSMutableSet set];
}

/// Written the way YouTube writes counts: 1.2K, 3.4M, and plain below a thousand.
///
/// Not NSByteCountFormatter's cousin NSNumberFormatter with a compact style -- that exists
/// only from iOS 16 and rounds differently. Beside a like count formatted by the app, a
/// dislike count rounded by a different rule reads as a mistake even when both are right.
static NSString *SCIShortCount(long long value) {
    if (value < 0) return nil;
    if (value < 1000) return [NSString stringWithFormat:@"%lld", value];

    double scaled = value;
    NSString *suffix = @"K";

    if (value >= 1000000000) { scaled = value / 1000000000.0; suffix = @"B"; }
    else if (value >= 1000000) { scaled = value / 1000000.0; suffix = @"M"; }
    else { scaled = value / 1000.0; }

    // One decimal below ten, none above -- 1.2K, then 12K. Trailing .0 is dropped, because
    // "12.0K" is not how any count on the screen beside it is written.
    NSString *number = (scaled < 10 && fmod(scaled * 10, 10) != 0)
        ? [NSString stringWithFormat:@"%.1f", scaled]
        : [NSString stringWithFormat:@"%.0f", scaled];

    return [number stringByAppendingString:suffix];
}

+ (NSString *)cachedCountFor:(NSString *)videoID {
    if (!videoID.length) return nil;

    @synchronized (sciCounts) {
        NSString *known = sciCounts[videoID];
        if (known) return known;
    }

    [self prepare:videoID];
    return nil;
}

+ (void)prepare:(NSString *)videoID {
    if (videoID.length != 11) return;

    @synchronized (sciCounts) {
        if (sciCounts[videoID]) return;
        if ([sciInFlight containsObject:videoID]) return;
        if ([sciMissing containsObject:videoID]) return;
        [sciInFlight addObject:videoID];
    }

    NSString *text = [NSString stringWithFormat:
        @"https://returnyoutubedislikeapi.com/votes?videoId=%@", videoID];
    NSURL *url = [NSURL URLWithString:text];
    if (!url) return;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 8;

    // Nothing identifying is attached. The id is the whole of the question.
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data,
                                                         NSURLResponse *response,
                                                         NSError *error) {
        void (^forget)(NSString *) = ^(NSString *state) {
            @synchronized (sciCounts) {
                [sciInFlight removeObject:videoID];
                [sciMissing addObject:videoID];
            }
            sciLastState = state;
        };

        if (error || !data.length) {
            forget(error.localizedDescription ?: @"no answer");
            return;
        }

        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status != 200) {
            forget([NSString stringWithFormat:@"HTTP %ld", (long)status]);
            return;
        }

        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![parsed isKindOfClass:[NSDictionary class]]) {
            forget(@"unreadable answer");
            return;
        }

        id number = parsed[@"dislikes"];
        if (![number isKindOfClass:[NSNumber class]]) {
            forget(@"no dislikes field");
            return;
        }

        NSString *formatted = SCIShortCount([number longLongValue]);
        if (!formatted) {
            forget(@"negative count");
            return;
        }

        @synchronized (sciCounts) {
            sciCounts[videoID] = formatted;
            [sciInFlight removeObject:videoID];
        }
        sciLastState = [NSString stringWithFormat:@"%@ → %@", videoID, formatted];
        SCILogV(@"dislikes: %@", sciLastState);

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:SCIYTDislikesDidArriveNotification object:videoID];
        });
    }] resume];
}

+ (NSString *)lastState { return sciLastState ?: @"nothing asked yet"; }

@end
