#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"

///
/// The player: what keeps going, how far a tap jumps, and how fast it may run.
///
@interface SCIYTPlaybackPage : NSObject
@end

/// The intervals offered, with zero meaning "whatever YouTube does".
///
/// Seconds and not menu positions, for the same reason the quality caps are resolutions:
/// reordering this list must never quietly change what somebody chose.
static NSArray<NSNumber *> *SCISeekChoices(void) {
    return @[@0, @5, @10, @15, @30, @45, @60];
}

static NSString *SCISeekLabel(NSInteger seconds) {
    if (seconds <= 0) return SCILocalized(@"seek_default");
    return [NSString stringWithFormat:SCILocalized(@"seek_seconds_format"), (long)seconds];
}

/// Asks how far, and remembers.
///
/// Presented from the screen it was tapped on rather than from the key window — the settings
/// panel is itself presented over YouTube, and a sheet asking the window arrives underneath.
static void SCIAskForSeek(SCIYTSettingsHostController *host) {
    if (!host) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:SCILocalized(@"seek_seconds_note")
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSNumber *seconds in SCISeekChoices()) {
        [sheet addAction:[UIAlertAction actionWithTitle:SCISeekLabel(seconds.integerValue)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:seconds.integerValue
                                                       forKey:SCIPrefSeekSeconds];

            // Rebuilt rather than redrawn: the row's subtitle is the chosen value, and it is
            // made when the section is made.
            [host reloadSettings];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = host.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 0, 0);

    [host presentViewController:sheet animated:YES completion:nil];
}

@implementation SCIYTPlaybackPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:40
                                        title:SCILocalized(@"page_playback")
                                       detail:SCILocalized(@"page_playback_note")
                                       symbol:@"play.circle.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *player = [[SCISection alloc] init];
        player.title = SCILocalized(@"section_player");
        player.rows = @[
            [SCIRow switchRow:SCILocalized(@"background_playback")
                       detail:SCILocalized(@"background_playback_note")
                       symbol:@"speaker.wave.2.fill"
                      prefKey:SCIPrefBackgroundPlay],
            [SCIRow disclosureRow:SCILocalized(@"seek_seconds")
                           detail:SCISeekLabel(SCIPrefNumber(SCIPrefSeekSeconds))
                           symbol:@"goforward"
                           action:^{ SCIAskForSeek(host); }],
            [SCIRow switchRow:SCILocalized(@"extra_speeds")
                       detail:SCILocalized(@"extra_speeds_note")
                       symbol:@"gauge.high"
                      prefKey:SCIPrefExtraSpeeds],
        ];

        // Its own section, with the warning as the footer rather than as the row's subtitle.
        // A subtitle is read after the switch has been reached for; a footer is read while
        // deciding whether to reach for it, and this is a switch that can cost playback.
        SCISection *experiment = [[SCISection alloc] init];
        experiment.title = SCILocalized(@"section_experimental");
        experiment.footer = SCILocalized(@"bypass_sabr_footer");
        experiment.rows = @[
            [SCIRow switchRow:SCILocalized(@"bypass_sabr")
                       detail:SCILocalized(@"bypass_sabr_note")
                       symbol:@"flask"
                      prefKey:SCIPrefBypassSABR],
        ];

        return @[player, experiment];
    }];
}

@end
