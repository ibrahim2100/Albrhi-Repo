#import "../SCIYTSettingsRegistry.h"
#import "../../Tweak.h"
#import "../../Localization/SCILocalize.h"

///
/// Who made this, under what licence, and what it borrows.
///
/// Last section on the screen, and the only one that is not a setting. It is here because
/// the licence requires it and because a tweak that talks to an outside service should
/// say so somewhere a user can find without being told where to look.
///
/// The SponsorBlock credit also appears beside the switch that turns it on, which is the
/// more useful place for it -- this repeats the attribution rather than replacing it, since
/// a credit shown only to people who scrolled to one particular switch is not published.
///
@interface SCIYTAboutPage : NSObject
@end

@implementation SCIYTAboutPage

+ (void)load {
    [SCIYTSettingsRegistry registerPageWithOrder:95
                                        title:SCILocalized(@"page_about")
                                       detail:SCILocalized(@"page_about_note")
                                       symbol:@"info.circle.fill"
                                      builder:^NSArray<SCISection *> *(__unused SCIYTSettingsHostController *host) {
        SCISection *about = [[SCISection alloc] init];
        about.title = SCILocalized(@"about_title");
        about.rows = @[
            [SCIRow disclosureRow:SCILocalized(@"about_author")
                           detail:SCILocalized(@"about_author_note")
                           symbol:@"person.fill"
                           action:^{ }],
            [SCIRow disclosureRow:SCILocalized(@"about_version")
                           detail:SCIVersionString
                           symbol:@"number"
                           action:^{ }],
            [SCIRow disclosureRow:SCILocalized(@"about_licence")
                           detail:SCILocalized(@"about_licence_note")
                           symbol:@"doc.text"
                           action:^{ }],
        ];

        // The source, because GPLv3 requires it to be offered and because a tweak asking for
        // this much trust should be readable by whoever wants to read it.
        about.footer = SCILocalized(@"about_footer");
        return @[about];
    }];
}

@end
