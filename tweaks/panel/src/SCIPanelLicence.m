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

    // Provisioned here, because this is the one process that may write the domain every tweak
    // reads. Until it has run, a sandboxed app and this page would answer two different device
    // ids -- which is exactly the fault that made 1.70.0 refuse a licence it had just accepted.
    SCILicenseProvisionDevice();

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

    // The *term*, not the renewal date. A server-signed licence is renewed every seven days, and
    // showing that as the expiry to somebody who bought a year is a screen that generates a
    // support message on its own.
    NSTimeInterval term = SCILicenseTermEnds();
    if (term > 0) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;

        [specifiers addObject:[self factTitled:SCILocalized(@"lic_until")
                                         value:[formatter stringFromDate:
                                                   [NSDate dateWithTimeIntervalSince1970:term]]
                                        symbol:@"calendar"
                                          tint:[UIColor systemIndigoColor]]];
    }

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

    // The server, if there is one. Above the asking, because whether a server is configured is
    // what decides *how* asking works -- with one, a request is sent and answered; without one,
    // it is a text you carry to the seller yourself.
    NSString *server = SCILicenseServerBase();

    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_server_section")
                                     footer:server ? SCILocalized(@"lic_server_footer")
                                                   : SCILocalized(@"lic_server_none_footer")]];

    [specifiers addObject:[self factTitled:SCILocalized(@"lic_server")
                                     value:server ?: SCILocalized(@"lic_server_none")
                                    symbol:@"antenna.radiowaves.left.and.right"
                                      tint:server ? [UIColor systemTealColor]
                                                  : [UIColor systemGrayColor]]];

    PSSpecifier *setServer = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_server_set")
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:Nil
                                                              cell:PSButtonCell
                                                              edit:Nil];
    SCISetButtonAction(setServer, @selector(setServerAddress));
    [specifiers addObject:setServer];

    if (server) {
        PSSpecifier *sync = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_sync")
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:Nil
                                                             cell:PSButtonCell
                                                             edit:Nil];
        SCISetButtonAction(sync, @selector(syncNow));
        [specifiers addObject:sync];
    }

    // Asking for one, and redeeming a code. Both above the gate and below the state, because
    // this is the order somebody actually moves through the page: what am I, what have I got,
    // how do I get one.
    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_get_section")
                                     footer:SCILocalized(@"lic_get_footer")]];

    PSSpecifier *request = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_request")
                                                          target:self
                                                             set:NULL
                                                             get:NULL
                                                          detail:Nil
                                                            cell:PSButtonCell
                                                            edit:Nil];
    SCISetButtonAction(request, @selector(makeRequest));
    [specifiers addObject:request];

    PSSpecifier *redeem = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_redeem")
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:Nil
                                                           cell:PSButtonCell
                                                           edit:Nil];
    SCISetButtonAction(redeem, @selector(redeemCode));
    [specifiers addObject:redeem];

    if (SCILicenseRedeemedCode()) {
        [specifiers addObject:[self factTitled:SCILocalized(@"lic_code_in_use")
                                         value:SCILicenseRedeemedCode()
                                        symbol:@"ticket"
                                          tint:[UIColor systemPurpleColor]]];

        PSSpecifier *forget = [PSSpecifier preferenceSpecifierNamed:SCILocalized(@"lic_forget_code")
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
        SCISetButtonAction(forget, @selector(forgetCode));
        [specifiers addObject:forget];
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
    // Refused rather than copied while the identity is provisional. A key issued against a
    // provisional id fits nothing at all, and the person would find that out on the phone that
    // just told them the licence was accepted.
    if (SCILicenseFingerprintIsWeak()) {
        [self tell:SCILocalized(@"lic_device_provisional")];
        return;
    }

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

///
/// Asks for a duration, then produces the request text.
///
/// **A share sheet, not just a clipboard.** The whole point is that this string has to reach
/// somebody else, and on a phone that means the app the person already talks to their seller in.
/// Copying is offered too, because a share sheet on a jailbroken Settings is not a thing to
/// depend on alone.
///
- (void)makeRequest {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"lic_request")
                                            message:SCILocalized(@"lic_request_note")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = SCILocalized(@"lic_request_days");
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.text = @"365";
    }];
    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = SCILocalized(@"lic_request_who");
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_request_make")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSInteger days = sheet.textFields.firstObject.text.integerValue;
        NSString *note = sheet.textFields.lastObject.text;

        // With a server, the request is *sent*. Without one, it becomes a text to carry to the
        // seller by hand -- which is what shipped before the server existed and remains the way
        // back in if it is ever unreachable.
        if (SCILicenseServerBase()) {
            SCILicenseRequestFromServer(days, note, ^(SCILicenseServerResult result) {
                [weakSelf tell:result == SCILicenseServerPending
                                    ? SCILocalized(@"lic_request_sent")
                                    : SCILocalized(@"lic_sync_unreachable")];
                [weakSelf reloadSpecifiers];
            });
            return;
        }

        NSString *request = SCILicenseMakeRequest(days, note);
        if (!request.length) { [weakSelf tell:SCILocalized(@"lic_request_failed")]; return; }

        [weakSelf shareRequest:request];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)shareRequest:(NSString *)request {
    [UIPasteboard generalPasteboard].string = request;

    UIAlertController *done =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"lic_request_ready")
                                            message:request
                                     preferredStyle:UIAlertControllerStyleAlert];

    [done addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_request_share")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        UIActivityViewController *share =
            [[UIActivityViewController alloc] initWithActivityItems:@[request]
                                              applicationActivities:nil];

        // An iPad refuses a popover with no anchor, and Settings runs there too.
        share.popoverPresentationController.sourceView = self.view;
        share.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);

        [self presentViewController:share animated:YES completion:nil];
    }]];

    [done addAction:[UIAlertAction actionWithTitle:SCILocalized(@"ok_button")
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:done animated:YES completion:nil];
}

///
/// Redeeming a short code.
///
/// The one place in this whole layer that needs the network, and it needs it once: the code is
/// twelve characters and cannot carry a signature, so the device hashes it and looks that hash up
/// in a published list. Afterwards the licence is local.
///
- (void)redeemCode {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"lic_redeem")
                                            message:SCILocalized(@"lic_redeem_note")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"ALB-XXXX-XXXX-XXXX";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_redeem_go")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *typed = sheet.textFields.firstObject.text;

        SCILicenseRedeemWithServer(typed, ^(SCILicenseRedeemResult result) {
            NSString *message;
            switch (result) {
                case SCILicenseRedeemedOK:          message = SCILocalized(@"lic_redeem_ok"); break;
                case SCILicenseRedeemMalformed:     message = SCILocalized(@"lic_redeem_bad"); break;
                case SCILicenseRedeemUnknown:       message = SCILocalized(@"lic_redeem_unknown"); break;
                case SCILicenseRedeemWindowClosed:  message = SCILocalized(@"lic_redeem_late"); break;
                case SCILicenseRedeemOffline:       message = SCILocalized(@"lic_redeem_offline"); break;
                case SCILicenseRedeemTaken:         message = SCILocalized(@"lic_redeem_taken"); break;
            }
            [weakSelf tell:message];
            [weakSelf reloadSpecifiers];
        });
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)setServerAddress {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"lic_server_set")
                                            message:SCILocalized(@"lic_server_set_note")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://albrhi-licence.….workers.dev";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.text = SCILicenseServerBase() ?: @"https://";
    }];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_apply")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *typed = sheet.textFields.firstObject.text;
        SCILicenseSetServerBase(typed);

        // Said rather than assumed: `SCILicenseServerBase` refuses anything that is not https,
        // and a silently rejected address would look exactly like a server that is down.
        if (typed.length > 8 && !SCILicenseServerBase()) {
            [weakSelf tell:SCILocalized(@"lic_server_bad")];
        } else {
            [weakSelf syncNow];
        }
        [weakSelf reloadSpecifiers];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_server_clear")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        SCILicenseSetServerBase(nil);
        [weakSelf reloadSpecifiers];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)syncNow {
    __weak __typeof(self) weakSelf = self;
    SCILicenseSyncWithServer(^(SCILicenseServerResult result) {
        NSString *message;
        switch (result) {
            case SCILicenseServerOK:            message = SCILocalized(@"lic_sync_ok"); break;
            case SCILicenseServerPending:       message = SCILocalized(@"lic_sync_pending"); break;
            case SCILicenseServerNoLicence:     message = SCILocalized(@"lic_sync_none"); break;
            case SCILicenseServerRevoked:       message = SCILocalized(@"lic_sync_revoked"); break;
            case SCILicenseServerExpired:       message = SCILocalized(@"lic_sync_expired"); break;
            case SCILicenseServerUnreachable:   message = SCILocalized(@"lic_sync_unreachable"); break;
            case SCILicenseServerNotConfigured: message = SCILocalized(@"lic_server_none"); break;
        }
        [weakSelf tell:message];
        [weakSelf reloadSpecifiers];
    });
}

- (void)forgetCode {
    SCILicenseForgetCode();
    [self tell:SCILocalized(@"lic_code_forgotten")];
    [self reloadSpecifiers];
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

    // YES when absent, matching SCILicenseIsEnforced exactly. A switch that shows off while the
    // gate is on is a screen stating the opposite of what is happening -- which this project has
    // shipped once already, in NextUp, and wrote down afterwards.
    return @([stored isKindOfClass:[NSNumber class]] ? [stored boolValue] : YES);
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
