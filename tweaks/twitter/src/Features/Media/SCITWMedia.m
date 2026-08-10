#import "SCITWMedia.h"
#import "TwitterHeaders.h"
#import "SCILog.h"
#import <pthread.h>

/// How many are kept. Enough that what you were looking at a few minutes ago is still
/// there, and small enough that the list is scannable and the memory is nothing.
static const NSUInteger SCITWMediaLimit = 80;

@implementation SCITWMediaItem

- (NSString *)fileExtension {
    // From the URL's own path, not from the kind. X serves MP4 for both video and animated
    // GIFs -- its "GIFs" have not been GIFs for years -- and saving one as .gif produces a
    // file Photos refuses without saying why.
    NSString *extension = self.url.path.pathExtension.lowercaseString;
    if (extension.length && extension.length <= 4) return extension;

    return self.kind == SCITWMediaKindImage ? @"jpg" : @"mp4";
}

@end


static pthread_mutex_t _lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableArray<SCITWMediaItem *> *_items = nil;

@implementation SCITWMedia

+ (void)load {
    _items = [NSMutableArray array];
}

/// The best MP4 X offers for this video, or nil when it offers none.
///
/// Asks X's own picker first and walks the variants only if that answers nothing. Both
/// paths are here because each covers the other's failure: the picker knows rules this code
/// does not, and the loop keeps working if the picker is renamed in a future build.
+ (NSURL *)bestVideoURL:(TFSTwitterEntityMediaVideoInfo *)info {
    if (!info) return nil;

    SEL picker = @selector(highestBitrateVideoVariantURLWithContentType:andMaximumBitrate:);
    if ([info respondsToSelector:picker]) {
        NSString *chosen = [info highestBitrateVideoVariantURLWithContentType:@"video/mp4"
                                                           andMaximumBitrate:LLONG_MAX];
        if ([chosen isKindOfClass:[NSString class]] && chosen.length) {
            NSURL *url = [NSURL URLWithString:chosen];
            if (url) return url;
        }
    }

    if (![info respondsToSelector:@selector(variants)]) return nil;

    NSURL *best = nil;
    long long bestBitrate = -1;

    for (TFSTwitterEntityMediaVideoVariant *variant in info.variants) {
        if (![variant respondsToSelector:@selector(url)]) continue;

        NSString *type = [variant respondsToSelector:@selector(contentType)]
            ? variant.contentType : nil;

        // Playlists are skipped rather than downloaded. An m3u8 is a list of segments, not
        // a file, and saving it produces a few kilobytes of text that Photos will not open.
        // A live broadcast offers nothing else, which is why some rows say so instead of
        // failing after the tap.
        if (type.length && [type rangeOfString:@"mp4"].location == NSNotFound) continue;
        if ([variant.url rangeOfString:@".m3u8"].location != NSNotFound) continue;

        long long bitrate = [variant respondsToSelector:@selector(bitrate)] ? variant.bitrate : 0;
        if (bitrate <= bestBitrate) continue;

        NSURL *candidate = [NSURL URLWithString:variant.url];
        if (!candidate) continue;

        best = candidate;
        bestBitrate = bitrate;
    }

    return best;
}

/// The full-size original of an image.
///
/// X's timeline URLs carry a `name=` telling the server which size to send -- `small`,
/// `medium`, `900x900`. Saving one of those saves the thumbnail the timeline was showing,
/// which looks like a working download until the file is opened. `orig` is the size that
/// was uploaded.
+ (NSURL *)originalImageURL:(NSString *)string {
    if (!string.length) return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:string];
    if (!components) return [NSURL URLWithString:string];

    NSMutableArray<NSURLQueryItem *> *query = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"name"]) continue;
        [query addObject:item];
    }
    [query addObject:[NSURLQueryItem queryItemWithName:@"name" value:@"orig"]];
    components.queryItems = query;

    return components.URL ?: [NSURL URLWithString:string];
}

+ (void)capture:(id)mediaEntity {
    SCITWMediaItem *item = [self itemForEntity:mediaEntity];
    if (!item) return;

    pthread_mutex_lock(&_lock);

    // Seen again means moved to the top, not added twice. A timeline that scrolls a post
    // out of view and back rebuilds its model each time, so without this the list would be
    // one video repeated as many times as it passed the screen.
    NSUInteger existing = NSNotFound;
    for (NSUInteger i = 0; i < _items.count; i++) {
        if ([_items[i].identifier isEqualToString:item.identifier]) { existing = i; break; }
    }
    if (existing != NSNotFound) [_items removeObjectAtIndex:existing];

    [_items insertObject:item atIndex:0];
    while (_items.count > SCITWMediaLimit) [_items removeLastObject];

    pthread_mutex_unlock(&_lock);
}

+ (SCITWMediaItem *)itemForEntity:(id)mediaEntity {
    if (![mediaEntity isKindOfClass:NSClassFromString(@"TFSTwitterEntityMedia")]) return nil;

    TFSTwitterEntityMedia *media = mediaEntity;

    // Asked, not inferred. Every one of these is a question X answers about its own object,
    // and the alternative -- deciding from `mediaType` being 2 -- is a number whose meaning
    // is not written down anywhere and changes when X adds a media kind.
    BOOL isVideo = [media respondsToSelector:@selector(isVideo)] && [media isVideo];
    BOOL isGif = [media respondsToSelector:@selector(isAnimatedGif)] && [media isAnimatedGif];
    BOOL isImage = [media respondsToSelector:@selector(isImage)] && [media isImage];

    if ([media respondsToSelector:@selector(isDeadVideo)] && [media isDeadVideo]) return nil;

    SCITWMediaItem *item = [[SCITWMediaItem alloc] init];
    item.seen = [NSDate date];

    if (isVideo || isGif) {
        TFSTwitterEntityMediaVideoInfo *info =
            [media respondsToSelector:@selector(videoInfo)] ? media.videoInfo : nil;

        // A video with no playable variant is dropped here rather than listed and failed
        // later. A row that cannot do what it offers is worse than a row that is absent:
        // one is a missing feature, the other is a broken one.
        item.url = [self bestVideoURL:info];
        if (!item.url) return nil;

        item.kind = isGif ? SCITWMediaKindGif : SCITWMediaKindVideo;
        item.duration = [info respondsToSelector:@selector(duration)] ? info.duration : 0;
    } else if (isImage) {
        NSString *string = [media respondsToSelector:@selector(imageURLString)]
            ? media.imageURLString : nil;
        if (!string.length && [media respondsToSelector:@selector(mediaURL)]) {
            string = media.mediaURL.absoluteString;
        }

        item.url = [self originalImageURL:string];
        if (!item.url) return nil;

        item.kind = SCITWMediaKindImage;
    } else {
        return nil;
    }

    // Identity by X's own id where there is one, and by the resolved URL otherwise. The URL
    // is a fair fallback: two different pieces of media do not share one.
    NSString *identifier = nil;
    if ([media respondsToSelector:@selector(mediaID)]) identifier = media.mediaID;
    if (!identifier.length && [media respondsToSelector:@selector(mediaKey)]) {
        identifier = media.mediaKey;
    }
    item.identifier = identifier.length ? identifier : item.url.absoluteString;

    if ([media respondsToSelector:@selector(altText)]) item.note = media.altText;

    return item;
}

+ (NSArray<SCITWMediaItem *> *)recent {
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
