#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../../Features/Download/Center/SCIYTDownloadCenter.h"

///
/// Downloads.
///
/// The Centre itself is the first row rather than a setting, because it is the thing
/// someone opening this screen after saving a video came looking for.
///
@interface SCIYTDownloadsPage : NSObject
@end

@implementation SCIYTDownloadsPage

+ (void)load {
    [SCIYTSettingsRegistry registerSectionsWithOrder:10
                                             builder:^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *host) {
        SCISection *downloads = [[SCISection alloc] init];
        downloads.title = SCILocalized(@"set_downloads_title");
        downloads.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"set_open_centre")
                           detail:nil
                           symbol:@"arrow.down.circle.fill"
                           action:^{ [SCIYTDownloadCenter present]; }],
            [SCIRow switchRow:SCILocalized(@"set_tab_button")
                       detail:nil
                       symbol:@"square.grid.2x2"
                      prefKey:SCIPrefTabButton],
            [SCIRow switchRow:SCILocalized(@"set_shorts_button")
                       detail:SCILocalized(@"set_shorts_button_note")
                       symbol:@"play.rectangle.on.rectangle"
                      prefKey:SCIPrefShortsButton],
            [SCIRow switchRow:SCILocalized(@"set_auto_photos")
                       detail:SCILocalized(@"set_auto_photos_note")
                       symbol:@"photo.on.rectangle"
                      prefKey:SCIPrefAutoPhotos],
            [SCIRow switchRow:SCILocalized(@"set_finish_notice")
                       detail:SCILocalized(@"set_finish_notice_note")
                       symbol:@"bell.badge"
                      prefKey:SCIPrefFinishNotice],
            [SCIRow switchRow:SCILocalized(@"set_tidy_photos")
                       detail:SCILocalized(@"set_tidy_photos_note")
                       symbol:@"tray.and.arrow.up"
                      prefKey:SCIPrefTidyAfterPhotos],
            [SCIRow switchRow:SCILocalized(@"set_embed_artwork")
                       detail:SCILocalized(@"set_embed_artwork_note")
                       symbol:@"music.note.list"
                      prefKey:SCIPrefEmbedArtwork],
            [SCIRow switchRow:SCILocalized(@"set_lock_skip")
                       detail:SCILocalized(@"set_lock_skip_note")
                       symbol:@"lock.iphone"
                      prefKey:SCIPrefLockScreenSkip],
        ];
        return @[downloads];
    }];
}

@end
