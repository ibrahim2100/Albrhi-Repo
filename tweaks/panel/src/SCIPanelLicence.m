#import "SCIPanelLicence.h"
#import <Preferences/PSSpecifier.h>
#import "Localization/SCILocalize.h"
#import "SCIPanelBadge.h"
#import "SCIPanelButtonAction.h"
#import "shared/src/SCILicense.h"

static NSString *const kSCIPanelDomain = @"com.albrhi.panel";
static NSString *const kSCIEnforceKey  = @"licence_enforced";

@implementation SCIPanelLicenceController

#pragma mark - Rows

- (PSSpecifier *)groupTitled:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:(title ?: @"")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSGroupCell
                                                          edit:Nil];
    if (footer.length) [group setProperty:footer forKey:@"footerText"];
    return group;
}

/// A read-only row: a label on the left, a value on the right.
///
/// `PSStaticTextCell` would put the value underneath and wrap it; the fingerprint has to be read
/// out loud to whoever is issuing the key, so it belongs on one line beside its label.
- (PSSpecifier *)factTitled:(NSString *)title
                      value:(NSString *)value
                     symbol:(NSString *)symbol
                       tint:(UIColor *)tint {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:NULL
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:(value ?: @"—") forKey:@"value"];
    if (symbol.length) [row setProperty:SCIPanelBadgeImage(symbol, tint) forKey:@"iconImage"];
    return row;
}

#pragma mark - The page

- (NSArray *)specifiers {
    NSMutableArray *specifiers = [NSMutableArray array];

    // What this device is, first. Everything else on the page is about a key issued against it,
    // and a key cannot be issued at all until this string has been read off the screen.
    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_device_section")
                                     footer:SCILicenseFingerprintIsWeak()
                                                ? SCILocalized(@"lic_device_weak")
                                                : SCILocalized(@"lic_device_footer")]];

    [specifiers addObject:[self factTitled:SCILocalized(@"lic_device")
                                     value:SCILicenseFingerprint()
                                    symbol:@"iphone"
                                      tint:[UIColor systemBlueColor]]];

    PSSpecifier *copy = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_copy_device")
                                                       target:self
                                                          set:NULL
                                                          get:NULL
                                                       detail:Nil
                                                         cell:PSButtonCell
                                                         edit:Nil];
    SCISetButtonAction(copy, @selector(copyFingerprint));
    [specifiers addObject:copy];

    // The state, said in a sentence rather than as a word. "no key" and "key issued to another
    // device" both read as "off" if the row only shows a state name, and they need different
    // things done about them.
    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_status_section") footer:nil]];
    [specifiers addObject:[self factTitled:SCILocalized(@"lic_status")
                                     value:SCILicenseStatusLine()
                                    symbol:@"checkmark.seal"
                                      tint:[UIColor systemGreenColor]]];

    PSSpecifier *enter = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_enter")
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:Nil
                                                          cell:PSButtonCell
                                                          edit:Nil];
    SCISetButtonAction(enter, @selector(enterKey));
    [specifiers addObject:enter];

    if (SCILicenseStoredKey()) {
        PSSpecifier *remove = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_remove")
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
        SCISetButtonAction(remove, @selector(removeKey));
        [specifiers addObject:remove];
    }

    // The gate itself, last and with the plainest footer on the page.
    //
    // **Off by default and it stays off until somebody turns it on here.** The source has been
    // free for as long as it has existed; a release that both introduced this layer and enforced
    // it would stop every install already out there on the next update, before a single key had
    // been issued to fix them with.
    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_enforce_section")
                                     footer:SCILocalized(@"lic_enforce_footer")]];

    PSSpecifier *enforce = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_enforce")
                                                          target:self
                                                             set:@selector(setEnforce:specifier:)
                                                             get:@selector(enforceForSpecifier:)
                                                          detail:Nil
                                                            cell:PSSwitchCell
                                                            edit:Nil];
    [enforce setProperty:SCIPanelBadgeImage(@"lock", [UIColor systemOrangeColor])
                  forKey:@"iconImage"];
    [specifiers addObject:enforce];

    // Assigned to the ivar, not just returned. PSListController reads `_specifiers` directly in
    // places an override's return value never reaches, and a page that only returns its rows
    // opens to a black screen -- which this project shipped once and diagnosed on a device.
    _specifiers = specifiers;
    return _specifiers;
}

#pragma mark - Actions

- (void)copyFingerprint {
    [UIPasteboard generalPasteboard].string = SCILicenseFingerprint();
    [self tell:SCILocalized(@"lic_copied")];
}

- (void)enterKey {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"lic_enter")
                                            message:SCILocalized(@"lic_enter_note")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"ALB1.…";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.text = SCILicenseStoredKey() ?: @"";
    }];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_apply")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *text = sheet.textFields.firstObject.text;

        SCILicenseState state = SCILicenseStateNone;
        BOOL ok = SCILicenseStoreKey(text, &state);

        // The reason, not just a refusal. "expired", "issued to another device" and "not a key"
        // need three different things done about them, and a single "invalid" makes the person
        // holding a perfectly good key for their other phone think they were sold nothing.
        NSString *message = ok ? SCILocalized(@"lic_accepted") : SCILicenseDescribeState(state);
        [weakSelf tell:message];
        [weakSelf reloadSpecifiers];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)removeKey {
    SCILicenseForgetKey();
    [self tell:SCILocalized(@"lic_removed")];
    [self reloadSpecifiers];
}

- (id)enforceForSpecifier:(__unused PSSpecifier *)specifier {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)kSCIEnforceKey,
                                                        (__bridge CFStringRef)kSCIPanelDomain);
    id stored = (__bridge_transfer id)value;
    return @([stored isKindOfClass:[NSNumber class]] ? [stored boolValue] : NO);
}

- (void)setEnforce:(id)value specifier:(__unused PSSpecifier *)specifier {
    CFPreferencesSetAppValue((__bridge CFStringRef)kSCIEnforceKey,
                             (__bridge CFNumberRef)value,
                             (__bridge CFStringRef)kSCIPanelDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSCIPanelDomain);
    [self reloadSpecifiers];
}

- (void)tell:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok_button")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
