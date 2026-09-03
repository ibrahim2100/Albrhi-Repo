#import "SCIPanelLicence.h"
#import <Preferences/PSSpecifier.h>
#import "Localization/SCILocalize.h"
#import "shared/src/Prefs/SCIPanelBadge.h"
#import "shared/src/Prefs/SCIPanelButtonAction.h"
#import "shared/src/SCILicense.h"
#import "shared/src/SCIPanelGate.h"
#import "SCIPanelPlans.h"

static NSString *const kSCIPanelDomain = @"com.albrhi.panel";

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
///
/// **The getter is not optional, and this file shipped without it.** Setting the `value` property
/// and passing `get:NULL` reads like it should work and draws the title with an empty space after
/// it -- a `PSTitleValueCell` asks its specifier for a value *through the get selector*, and with
/// none there is nothing to ask. The licence state and the term were both blank on a device
/// because of it.
///
/// `SCIPanelRoot.m` had already found this, written it down in exactly those words, and fixed it
/// there. It was repeated here anyway, in a new file, which is why `tools/check.py` refuses the
/// shape now rather than leaving it to a comment in another file to prevent.
- (PSSpecifier *)factTitled:(NSString *)title
                      value:(NSString *)value
                     symbol:(NSString *)symbol
                       tint:(UIColor *)tint {
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:title
                                                      target:self
                                                         set:NULL
                                                         get:@selector(fixedValue:)
                                                      detail:Nil
                                                        cell:PSTitleValueCell
                                                        edit:Nil];
    [row setProperty:(value ?: @"—") forKey:@"value"];
    if (symbol.length) [row setProperty:SCIPanelBadgeImage(symbol, tint) forKey:@"iconImage"];
    return row;
}

/// A row that shows what it was given and cannot be edited.
- (id)fixedValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"value"] ?: @"";
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
    // A lifetime licence has no date to show, and a blank row where the date goes is exactly the
    // fault this page shipped with last week. It gets a word instead.
    if (SCILicenseIsLifetime()) {
        [specifiers addObject:[self factTitled:SCILocalized(@"lic_until")
                                         value:SCILocalized(@"lic_lifetime")
                                        symbol:@"infinity"
                                          tint:[UIColor systemIndigoColor]]];
    }

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

    //
    // **One row, not two.** «Enter a key» and «Enter a code» sat next to each other and read as
    // the same button written twice -- reported as exactly that. They are two instruments, but
    // that is a fact about how a licence was issued, not a question the person holding it should
    // have to answer: they were sent one string and they want to put it in.
    //
    // Which one it is, is decided by looking at it. A key begins `ALB1.`; anything else is a
    // code. Guessing wrong costs nothing, because the wrong path refuses and the right one is
    // tried after it.
    //
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

    // The server. Above the asking, because it is what decides *how* asking works: with one, the
    // request is sent and answered; without one, it becomes a text carried to the seller by hand.
    //
    // **Albrhi's own address is compiled in**, so this is filled on a phone that has never been
    // configured -- otherwise every buyer would have to be told a URL and type it correctly before
    // they could even ask, which is a support thread rather than a purchase. The row says which of
    // the two is in use, because "the default" and "one I chose" are different facts and only one
    // of them is worth checking when something stops working.
    NSString *server = SCILicenseServerBase();

    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_server_section")
                                     footer:server ? SCILocalized(@"lic_server_footer")
                                                   : SCILocalized(@"lic_server_none_footer")]];

    [specifiers addObject:[self factTitled:SCILocalized(@"lic_server")
                                     value:server ?: SCILocalized(@"lic_server_none")
                                    symbol:@"antenna.radiowaves.left.and.right"
                                      tint:server ? [UIColor systemTealColor]
                                                  : [UIColor systemGrayColor]]];


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

    // **No enforcement switch, and its absence is the feature.**
    //
    // One shipped, for one release, so the layer could be introduced before it was enforced. It
    // reached every user's phone, where it read as "turn licensing off" -- which it was. A gate
    // with an off switch on the far side of it is not a gate.
    //
    // What stands here instead is a statement of what is happening, because a tweak standing down
    // is indistinguishable from a broken install and somebody has to be told which.
    [specifiers addObject:[self groupTitled:SCILocalized(@"lic_enforce_section")
                                     footer:SCILocalized(@"lic_enforce_footer")]];

    [specifiers addObject:[self factTitled:SCILocalized(@"lic_enforce")
                                     value:SCILicenseAllows() ? SCILocalized(@"lic_running")
                                                              : SCILocalized(@"lic_stopped")
                                    symbol:SCILicenseAllows() ? @"checkmark.circle.fill"
                                                              : @"exclamationmark.triangle.fill"
                                      tint:SCILicenseAllows() ? [UIColor systemGreenColor]
                                                              : [UIColor systemOrangeColor]]];

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
        field.placeholder = @"ALB-XXXX-XXXX-XXXX";
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    __weak __typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"lic_apply")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *text = [sheet.textFields.firstObject.text stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // A signed key announces itself. Everything else is a short code, and the code path is
        // the one that can ask the server -- so an unrecognised string still gets a real answer
        // rather than "that is not a key".
        if ([text.uppercaseString hasPrefix:@"ALB1."]) {
            SCILicenseState state = SCILicenseStateNone;
            BOOL ok = SCILicenseStoreKey(text, &state);
            [weakSelf tell:ok ? SCILocalized(@"lic_accepted") : SCILicenseDescribeState(state)];
            [weakSelf reloadSpecifiers];
            return;
        }

        SCILicenseRedeemWithServer(text, ^(SCILicenseRedeemResult result) {
            NSString *message;
            switch (result) {
                case SCILicenseRedeemedOK:         message = SCILocalized(@"lic_redeem_ok"); break;
                case SCILicenseRedeemMalformed:    message = SCILocalized(@"lic_redeem_bad"); break;
                case SCILicenseRedeemUnknown:      message = SCILocalized(@"lic_redeem_unknown"); break;
                case SCILicenseRedeemWindowClosed: message = SCILocalized(@"lic_redeem_late"); break;
                case SCILicenseRedeemOffline:      message = SCILocalized(@"lic_redeem_offline"); break;

                // A code bound to somebody else's phone. Its own sentence, because "already
                // used" and "no such code" send a person to two different places -- one back to
                // whoever sold it, the other to check their typing.
                case SCILicenseRedeemTaken:        message = SCILocalized(@"lic_redeem_taken"); break;
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

///
/// Asks for a duration, then produces the request text.
///
/// **A share sheet, not just a clipboard.** The whole point is that this string has to reach
/// somebody else, and on a phone that means the app the person already talks to their seller in.
/// Copying is offered too, because a share sheet on a jailbroken Settings is not a thing to
/// depend on alone.
///
///
/// Opens the plans card.
///
/// It used to be a `UIAlertController` asking for a number of days — correct, and it looked like
/// an error dialog on the one screen where somebody decides whether to pay. The card is ours, it
/// prices the choices, and the free week is taken in it without leaving.
///
- (void)makeRequest {
    __weak __typeof(self) weakSelf = self;
    [SCIPanelPlans presentFrom:self change:^{ [weakSelf reloadSpecifiers]; }];
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

            // Neither can come back from a renewal -- they are answers to asking for the free
            // week. Named rather than swallowed by a `default:`, which would also silence the
            // next result added to the enum, and that warning is the reason this compiled wrong
            // once already.
            case SCILicenseServerTrialUsed:      message = SCILocalized(@"plans_trial_used"); break;
            case SCILicenseServerAlreadyLicensed:message = SCILocalized(@"plans_trial_have"); break;
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
