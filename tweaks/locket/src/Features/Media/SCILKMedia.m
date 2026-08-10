#import "SCILKMedia.h"
#import "SCILog.h"
#import <pthread.h>

static const NSUInteger SCILKMediaLimit = 60;

@implementation SCILKMediaItem
@end


static pthread_mutex_t _lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableArray<SCILKMediaItem *> *_items = nil;

@implementation SCILKMedia

+ (void)load {
    _items = [NSMutableArray array];
}

/// Whether a URL is a user moment's blob rather than a decorative asset or an API call.
///
/// Two storage hosts, and only the private objects. The public buckets — "locket-public",
/// anything with "public" in the path, the overlays and camera_filters and invites — are
/// art the app ships, not a photo a friend took. Everything else on those hosts that is
/// left is a user upload.
+ (BOOL)isMomentURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:@"firebasestorage.googleapis.com"] &&
        ![host isEqualToString:@"storage.googleapis.com"]) {
        return NO;
    }

    NSString *path = url.path.lowercaseString ?: @"";
    for (NSString *marker in @[@"public", @"overlays", @"camera_filters", @"invites",
                               @"assets", @"filters", @"stickers", @"fonts"]) {
        if ([path rangeOfString:marker].location != NSNotFound) return NO;
    }
    return YES;
}

+ (void)captureRequest:(NSURLRequest *)request {
    if (![request isKindOfClass:[NSURLRequest class]]) return;

    NSURL *url = request.URL;
    if (!url || ![self isMomentURL:url]) return;

    SCILKMediaItem *item = [[SCILKMediaItem alloc] init];
    item.url = url;
    item.host = url.host;
    item.seen = [NSDate date];

    // A readable tail: the last path component without the query, so the row shows something
    // a person can tell apart rather than a hundred characters of signed token.
    NSString *last = url.lastPathComponent ?: url.path;
    item.label = last.length > 40 ? [last substringToIndex:40] : last;

    // Identity by the object path without its token: the same moment is re-requested with a
    // fresh token each time it scrolls past, and keying on the whole URL would list one
    // photo many times. The path alone is stable per moment.
    NSString *identity = url.path ?: url.absoluteString;

    pthread_mutex_lock(&_lock);

    NSUInteger existing = NSNotFound;
    for (NSUInteger i = 0; i < _items.count; i++) {
        if ([(_items[i].url.path ?: _items[i].url.absoluteString) isEqualToString:identity]) {
            existing = i;
            break;
        }
    }
    if (existing != NSNotFound) {
        // Keep the newer URL — its token is fresh, and the stale one may no longer fetch.
        [_items removeObjectAtIndex:existing];
    }

    [_items insertObject:item atIndex:0];
    while (_items.count > SCILKMediaLimit) [_items removeLastObject];

    pthread_mutex_unlock(&_lock);
}

+ (NSArray<SCILKMediaItem *> *)recent {
    pthread_mutex_lock(&_lock);
    NSArray *snapshot = [_items copy];
    pthread_mutex_unlock(&_lock);
    return snapshot;
}

+ (void)forgetAll {
    pthread_mutex_lock(&_lock);
    [_items removeAllObjects];
    pthread_mutex_unlock(&_lock);
}

@end
