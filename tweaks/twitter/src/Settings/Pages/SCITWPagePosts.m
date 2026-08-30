#import "../Model/SCITWPageRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// The post itself: the row of buttons under it, and how its picture is drawn.
///
@interface SCITWPagePosts : NSObject
@end

@implementation SCITWPagePosts

+ (void)load {
    [SCITWPageRegistry registerPageWithOrder:40
                                   title:SCILocalized(@"section_posts")
                                    note:SCILocalized(@"section_posts_note")
                                  symbol:@"text.bubble.fill"
                                    tint:[UIColor systemIndigoColor]
                                 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        return @[
            [SCITWSection titled:SCILocalized(@"section_posts")
                          footer:SCILocalized(@"section_posts_note")
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"set_hide_bookmark")
                               note:nil
                             symbol:@"bookmark"
                               tint:[UIColor systemIndigoColor]
                            prefKey:SCIPrefHideBookmark],
                [SCITWRow switchRow:SCILocalized(@"set_tweet_to_image")
                               note:SCILocalized(@"set_tweet_to_image_note")
                             symbol:@"camera.viewfinder"
                               tint:[UIColor systemPinkColor]
                            prefKey:SCIPrefTweetToImage],
                [SCITWRow switchRow:SCILocalized(@"set_full_frame")
                               note:SCILocalized(@"set_full_frame_note")
                             symbol:@"rectangle.expand.vertical"
                               tint:[UIColor systemTealColor]
                            prefKey:SCIPrefFullFrameImages],
            ]],
        ];
    }];
}

@end
