#import "../Model/SCITWSectionRegistry.h"
#import "Features/Media/SCITWMedia.h"
#import "Features/Media/SCITWDownload.h"
#import "Localization/SCILocalize.h"

///
/// What has been captured, and one tap to save it.
///
/// Saved on the tap with no confirmation: nothing is destroyed and nothing is sent
/// anywhere, and a sheet asking "are you sure you want to keep this" protects against
/// nothing. This project puts confirmations only where a mis-tap becomes something
/// somebody else sees.
///
@interface SCITWSectionMedia : NSObject
@end

@implementation SCITWSectionMedia

+ (void)load {
    [SCITWSectionRegistry registerBuilderWithOrder:5 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        NSArray<SCITWMediaItem *> *media = [SCITWMedia recent];
        if (!media.count) return @[];

        NSMutableArray<SCITWRow *> *rows = [NSMutableArray array];
        for (SCITWMediaItem *item in media) {
            NSString *kind = SCILocalized(item.kind == SCITWMediaKindVideo ? @"media_video"
                                        : item.kind == SCITWMediaKindGif   ? @"media_gif"
                                                                           : @"media_image");

            // The alt text where the poster wrote one, and the kind where they did not.
            // "Video" eleven times down a list is a list nobody can pick from, and alt text
            // is the only caption X hands over for a piece of media.
            NSMutableArray<NSString *> *detail = [NSMutableArray arrayWithObject:kind];
            if (item.duration > 0.5) {
                [detail addObject:[NSString stringWithFormat:@"%d:%02d",
                    (int)(item.duration / 60), (int)item.duration % 60]];
            }

            NSString *icon = item.kind == SCITWMediaKindImage ? @"photo.fill"
                                                              : @"play.rectangle.fill";
            UIColor *tint = item.kind == SCITWMediaKindImage ? [UIColor systemBlueColor]
                                                             : [UIColor systemPurpleColor];

            [rows addObject:[SCITWRow actionRow:(item.note.length ? item.note : kind)
                                           note:[detail componentsJoinedByString:@" \u00b7 "]
                                         symbol:icon
                                           tint:tint
                                         action:^{ [SCITWDownload save:item]; }]];
        }

        return @[[SCITWSection titled:SCILocalized(@"section_media")
                               footer:SCILocalized(@"media_footer")
                                 rows:rows]];
    }];
}

@end
