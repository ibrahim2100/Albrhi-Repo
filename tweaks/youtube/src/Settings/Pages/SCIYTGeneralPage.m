#import "../SCIYTSettingsRegistry.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"
#import "../../Features/Download/SCIYTDownload.h"

///
/// General, and the two ways out of it: saving the video being watched, and the report.
///
/// Last by design. This is the section someone reaches by scrolling past everything they
/// came for.
///
@interface SCIYTGeneralPage : NSObject
@end

/// Opens the report, or says where it is if the page will not build.
///
/// Wrapped for the same reason the panel itself is: this page reads objects YouTube gave us
/// and prints them, and it went unguarded while the panel around it was protected. The
/// report is on disk either way, which is the point of writing it there.
static void SCIOpenDiagnostics(SCIYTSettingsHostController *host) {
    if (!host) return;

    UIViewController *page = nil;

    @try {
        page = [SCIYTDiagnostics viewController];
    } @catch (NSException *exception) {
        [SCIYTDiagnostics recordPanelFailure:
            [NSString stringWithFormat:@"diagnostics page: %@", exception.reason]];
        SCILogV(@"diagnostics page could not be built: %@", exception.reason);
    }

    if (page) {
        [host.navigationController pushViewController:page animated:YES];
        return;
    }

    // Says where the report is rather than failing silently -- the file is the way out when
    // the page is not.
    NSString *path = [SCIYTDiagnostics writeReportToFile];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:SCILocalized(@"diag_title")
                         message:[NSString stringWithFormat:SCILocalized(@"diag_page_failed"),
                                  path ?: @"Documents/AlbrhiYT-report.txt"]
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [host presentViewController:alert animated:YES completion:nil];
}

@implementation SCIYTGeneralPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:90
                                        title:SCILocalized(@"page_general")
                                       detail:SCILocalized(@"page_general_note")
                                       symbol:@"gearshape.fill"
                                      builder:^NSArray<SCISection *> *(SCIYTSettingsHostController *host) {
        SCISection *general = [[SCISection alloc] init];
        general.title = SCILocalized(@"section_general");
        general.rows = @[
            [SCIRow switchRow:SCILocalized(@"block_update_nag")
                       detail:SCILocalized(@"block_update_nag_note")
                       symbol:@"bell.slash.fill"
                      prefKey:SCIPrefBlockUpdateNag],
            [SCIRow switchRow:SCILocalized(@"verbose_logging")
                       detail:SCILocalized(@"verbose_logging_note")
                       symbol:@"text.alignleft"
                      prefKey:SCIPrefVerboseLogging],
            [SCIRow disclosureRow:SCILocalized(@"dl_row")
                           detail:SCILocalized(@"dl_row_note")
                           symbol:@"arrow.down.circle.fill"
                           action:^{ [SCIYTDownload presentFrom:host]; }],
            [SCIRow disclosureRow:SCILocalized(@"scan_watch")
                           detail:SCILocalized(@"scan_watch_note")
                           symbol:@"viewfinder"
                           action:^{
                               [SCIYTDiagnostics scanWatchPage];

                               // Said plainly, because a scan that writes into a page you are
                               // not looking at is indistinguishable from a row that does
                               // nothing -- which is a mistake this project has made twice on
                               // two different apps.
                               UIAlertController *done = [UIAlertController
                                   alertControllerWithTitle:nil
                                                    message:SCILocalized(@"scan_done")
                                             preferredStyle:UIAlertControllerStyleAlert];
                               [done addAction:[UIAlertAction
                                   actionWithTitle:SCILocalized(@"ok")
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
                               [host presentViewController:done animated:YES completion:nil];
                           }],
            [SCIRow disclosureRow:SCILocalized(@"diagnostics")
                           detail:SCILocalized(@"diagnostics_note")
                           symbol:@"stethoscope"
                           action:^{ SCIOpenDiagnostics(host); }],
        ];

        // How to get back here. A two-finger long press is safe and reliable and completely
        // undiscoverable, which is the trade it makes.
        general.footer = SCILocalized(@"panel_subtitle");
        return @[general];
    }];
}

@end
