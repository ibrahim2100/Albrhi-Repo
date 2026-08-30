#import "../Model/SCITWSectionRegistry.h"
#import "Prefs.h"
#import "Localization/SCILocalize.h"

///
/// Things the timeline puts between the posts.
///
/// Every row here *removes* something that works, which is why they are together under one
/// heading and every one of them ships off: taking a module away is a choice, and choosing
/// it for everybody is not this tweak's call.
///
@interface SCITWSectionTimeline : NSObject
@end

@implementation SCITWSectionTimeline

+ (void)load {
    [SCITWSectionRegistry registerBuilderWithOrder:30 builder:^NSArray<SCITWSection *> *(__unused UIViewController *host) {
        return @[
            [SCITWSection titled:SCILocalized(@"section_timeline")
                          footer:SCILocalized(@"section_timeline_note")
                            rows:@[
                [SCITWRow switchRow:SCILocalized(@"albrhi_hide_promoted")
                               note:SCILocalized(@"albrhi_hide_promoted_note")
                             symbol:@"megaphone.fill"
                               tint:[UIColor systemOrangeColor]
                            prefKey:SCIPrefHidePromoted],
                [SCITWRow switchRow:SCILocalized(@"albrhi_hide_suggested")
                               note:SCILocalized(@"albrhi_hide_suggested_note")
                             symbol:@"person.2.fill"
                               tint:[UIColor systemOrangeColor]
                            prefKey:SCIPrefHideSuggested],
                [SCITWRow switchRow:SCILocalized(@"set_hide_who_to_follow")
                               note:SCILocalized(@"set_hide_who_to_follow_note")
                             symbol:@"person.crop.circle.badge.plus"
                               tint:[UIColor systemOrangeColor]
                            prefKey:SCIPrefHideWhoToFollow],
                [SCITWRow switchRow:SCILocalized(@"set_hide_topics")
                               note:SCILocalized(@"set_hide_topics_note")
                             symbol:@"number"
                               tint:[UIColor systemOrangeColor]
                            prefKey:SCIPrefHideTopics],
                [SCITWRow switchRow:SCILocalized(@"set_hide_trend_videos")
                               note:SCILocalized(@"set_hide_trend_videos_note")
                             symbol:@"play.square.stack"
                               tint:[UIColor systemOrangeColor]
                            prefKey:SCIPrefHideTrendVideos],
            ]],
        ];
    }];
}

@end
