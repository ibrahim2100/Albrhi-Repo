#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"

@interface SCIYTPlaybackPage : NSObject
@end

@implementation SCIYTPlaybackPage

+ (void)load {
    [SCIYTSettingsRegistry registerSectionsWithOrder:40
                                             builder:^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *host) {
        SCISection *player = [[SCISection alloc] init];
        player.title = SCILocalized(@"section_player");
        player.rows = @[
            [SCIRow switchRow:SCILocalized(@"background_playback")
                       detail:SCILocalized(@"background_playback_note")
                       symbol:@"speaker.wave.2.fill"
                      prefKey:SCIPrefBackgroundPlay],
        ];
        return @[player];
    }];
}

@end
