#import "SCILicenseUI.h"
#import "SCILicense.h"
#import "SCIPanelGate.h"

///
/// The screen itself.
///
/// A plain `UIViewController` with a stack view in a scroll view, because that is the one shape
/// that works in every app this ships into: a `UITableViewController` brings its own scrolling
/// and its own idea of what a cell is, and four host apps have four different ideas about both.
///
/// **The scroll view's content is pinned to it *and* given a width**, which is the mistake the
/// panel's plans card made and reported as "a small empty box": pinning content to a scroll view
/// sets `contentSize`, and without the width constraint the content is free to be zero wide.
///
@interface SCILicenseUIController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *deviceLabel;
@property (nonatomic, strong) UITextField *entry;
@end

@implementation SCILicenseUIController

/// Localised without a table.
///
/// This file is compiled into four tweaks that each carry their own `SCILocalize.m`, and importing
/// one of them here would mean this shared file reading whichever table happened to resolve first
/// — the exact ambiguity `SCILocalizeAPI.h` was written to end for the preference-bundle kit. Two
/// languages, inline, is the smaller price: there are fourteen strings and they are all about one
/// subject.
static NSString *SCIText(NSString *english, NSString *arabic) {
    NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    return [language hasPrefix:@"ar"] ? arabic : english;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = SCIText(@"Licence", @"الترخيص");

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(close)];

    UIScrollView *scroller = [[UIScrollView alloc] init];
    scroller.translatesAutoresizingMaskIntoConstraints = NO;
    scroller.alwaysBounceVertical = YES;
    [self.view addSubview:scroller];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [scroller addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroller.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroller.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroller.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroller.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroller.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:scroller.bottomAnchor constant:-20],
        [stack.leadingAnchor constraintEqualToAnchor:scroller.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroller.trailingAnchor constant:-20],

        // The width, without which the content is free to be zero wide and the screen reads as
        // empty. `contentSize` is what pinning to the edges above sets; it is not a size.
        [stack.widthAnchor constraintEqualToAnchor:scroller.widthAnchor constant:-40],
    ]];

    self.statusLabel = [self label:@"" bold:YES];
    self.deviceLabel = [self label:@"" bold:NO];
    self.deviceLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];

    [stack addArrangedSubview:self.statusLabel];
    [stack addArrangedSubview:[self note:SCIText(
        @"Albrhi needs a licence. Without one the tweak installs nothing and the app behaves as if it were not there.",
        @"البرهي يحتاج ترخيصاً. بلا ترخيص لا تُركّب الأداة شيئاً ويتصرّف التطبيق كأنها غير موجودة.")]];

    // **A store copy says so, at the top, before anything about keys.**
    //
    // Somebody who bought this in a shop did not buy a licence to a device and should not be
    // asked to think about one. The screen names the shop, gives the one code, and says when the
    // copy stops -- which is the only part of it that will ever surprise anybody.
    if (SCILicenseStoreID().length) {
        NSDateFormatter *when = [[NSDateFormatter alloc] init];
        when.dateStyle = NSDateFormatterMediumStyle;
        when.timeStyle = NSDateFormatterNoStyle;
        NSString *until = [when stringFromDate:
            [NSDate dateWithTimeIntervalSince1970:SCILicenseStoreExpiry()]];

        [stack addArrangedSubview:[self heading:SCIText(@"This copy", @"هذه النسخة")]];

        UILabel *store = [self label:[NSString stringWithFormat:
            SCIText(@"A copy for %@ — %@", @"نسخة خاصة بـ%@ — %@"),
            SCILicenseStoreName() ?: SCILicenseStoreID(),
            SCILicenseStoreSite() ?: @""] bold:NO];
        store.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [stack addArrangedSubview:store];

        [stack addArrangedSubview:[self note:[NSString stringWithFormat:
            SCIText(@"One code for every device: type %@ below. This copy works until %@, after "
                    @"which the store has a new one.",
                    @"كودٌ واحد لكل الأجهزة: اكتب %@ في الأسفل. هذه النسخة تعمل حتى %@، وبعدها "
                    @"يوفّر المتجر نسخةً جديدة."),
            SCILicenseStoreID().uppercaseString, until]]];
    }

    // **Said only where it is true.** On a jailbreak with the panel installed, one activation
    // there licenses every tweak on the phone -- entering a key here writes to the same place, so
    // both routes work, but pointing at the one screen that covers everything is the better
    // answer. On a sideloaded install there is no panel and this screen is the only route.
    if (SCIPanelIsInstalled()) {
        [stack addArrangedSubview:[self note:SCIText(
            @"Albrhi Panel is installed on this device: activating there licenses every Albrhi tweak at once, and a key entered here does the same thing.",
            @"بانل البرهي مثبَّت على هذا الجهاز: التفعيل منه يرخّص كل أدوات البرهي دفعةً واحدة، ومفتاحٌ يُدخَل هنا يفعل الشيء نفسه.")]];
    }

    [stack addArrangedSubview:[self heading:SCIText(@"This device", @"هذا الجهاز")]];
    [stack addArrangedSubview:self.deviceLabel];
    [stack addArrangedSubview:[self button:SCIText(@"Copy device code", @"نسخ رمز الجهاز")
                                   action:@selector(copyDevice)
                                  primary:NO]];
    [stack addArrangedSubview:[self note:SCIText(
        @"Send this to get a key. It is a one-way value provisioned on this device — it is not a serial number and cannot be turned back into one.",
        @"أرسله للحصول على مفتاح. قيمة تُنشأ على هذا الجهاز باتجاهٍ واحد — ليست رقماً تسلسلياً ولا يمكن إرجاعها إليه.")]];

    [stack addArrangedSubview:[self heading:SCIText(@"Enter a licence", @"إدخال ترخيص")]];

    self.entry = [[UITextField alloc] init];
    self.entry.borderStyle = UITextBorderStyleRoundedRect;
    self.entry.autocorrectionType = UITextAutocorrectionTypeNo;
    self.entry.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.entry.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.entry.placeholder = SCIText(@"ALB1.… or ALB-XXXX-XXXX-XXXX",
                                     @"ALB1.… أو ALB-XXXX-XXXX-XXXX");
    [self.entry.heightAnchor constraintEqualToConstant:44].active = YES;
    [stack addArrangedSubview:self.entry];

    [stack addArrangedSubview:[self button:SCIText(@"Apply", @"تفعيل")
                                   action:@selector(apply)
                                  primary:YES]];
    [stack addArrangedSubview:[self note:SCIText(
        @"Paste whatever you were sent — a short code or a long key. Albrhi works out which.",
        @"الصق ما وصلك — كوداً قصيراً أو مفتاحاً طويلاً. البرهي يعرف أيّهما.")]];

    [stack addArrangedSubview:[self button:SCIText(@"Ask the server now", @"اسأل الخادم الآن")
                                   action:@selector(sync)
                                  primary:NO]];
    [stack addArrangedSubview:[self button:SCIText(@"Remove the key", @"إزالة المفتاح")
                                   action:@selector(remove)
                                  primary:NO]];

    [self refresh];
}

#pragma mark - Small pieces

- (UILabel *)label:(NSString *)text bold:(BOOL)bold {
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.text = text;
    label.font = bold ? [UIFont boldSystemFontOfSize:17] : [UIFont systemFontOfSize:15];
    return label;
}

- (UILabel *)heading:(NSString *)text {
    UILabel *label = [self label:[text uppercaseString] bold:NO];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (UILabel *)note:(NSString *)text {
    UILabel *label = [self label:text bold:NO];
    label.font = [UIFont systemFontOfSize:13];
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (UIButton *)button:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:primary ? UIFontWeightSemibold
                                                                        : UIFontWeightRegular];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:34].active = YES;
    return button;
}

- (void)say:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SCIText(@"OK", @"حسنًا")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - State

- (void)refresh {
    self.statusLabel.text = SCILicenseStatusLine();

    // A store copy is licensed or it is not, and the ordinary status line -- written for keys,
    // servers and grace periods -- describes none of that.
    if (SCILicenseStoreID().length) {
        self.statusLabel.text = SCILicenseStoreActive()
            ? SCIText(@"Active", @"مفعَّلة")
            : SCIText(@"Not activated — enter the code below", @"غير مفعَّلة — اكتب الكود في الأسفل");
    }

    NSString *device = SCILicenseFingerprint();
    self.deviceLabel.text = device.length ? device : SCIText(@"not created yet", @"لم يُنشأ بعد");

    // What the licence covers, said only when it is narrower than everything: "this key is for
    // YouTube" is worth knowing, and "this key is for everything" is noise on a screen inside one
    // app.
    NSString *scope = SCILicenseScope();
    if ([scope hasPrefix:@"app:"]) {
        self.statusLabel.text = [NSString stringWithFormat:@"%@ · %@",
            self.statusLabel.text,
            [NSString stringWithFormat:SCIText(@"for %@ only", @"لـ%@ وحدها"),
                [scope substringFromIndex:4]]];
    }
}

#pragma mark - Actions

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyDevice {
    NSString *device = SCILicenseFingerprint();
    if (!device.length || SCILicenseFingerprintIsWeak()) {
        [self say:SCIText(@"This device has no id yet. Leave this screen and open it again, then try.",
                          @"لا يوجد رمز لهذا الجهاز بعد. أغلق هذه الشاشة وافتحها ثانيةً ثم أعد المحاولة.")];
        return;
    }

    [UIPasteboard generalPasteboard].string = device;
    [self say:SCIText(@"Copied.", @"نُسخ.")];
}

/// One row for two instruments, deciding by shape.
///
/// Which of the two somebody holds is a fact about how their licence was issued, not something
/// they should have to classify — the panel learned that when «enter a key» and «enter a code»
/// sat side by side and were reported as the same button twice.
- (void)apply {
    NSString *text = [self.entry.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;

    [self.view endEditing:YES];

    // The store's own code, tried first and only where such a build exists. It is not a key and
    // not a short code: it goes to neither the verifier nor the server.
    if (SCILicenseStoreAccepts(text)) {
        SCILicenseStoreRemember(text);
        self.entry.text = @"";
        [self refresh];
        [self say:SCIText(@"Activated.", @"فُعِّلت.")];
        return;
    }

    if ([text hasPrefix:@"ALB1."]) {
        SCILicenseState state = SCILicenseStateNone;
        if (SCILicenseStoreKey(text, &state)) {
            self.entry.text = @"";
            [self refresh];
            [self say:SCIText(@"Key accepted.", @"قُبل المفتاح.")];
        } else {
            [self say:SCILicenseDescribeState(state)];
        }
        return;
    }

    // Anything else goes down the path that can ask the server, so an unrecognised string still
    // gets a real answer rather than "that is not a key".
    SCILicenseRedeemCode(text, ^(SCILicenseRedeemResult result) {
        [self refresh];

        switch (result) {
            case SCILicenseRedeemedOK:
                self.entry.text = @"";
                [self say:SCIText(@"Code accepted.", @"قُبل الكود.")];
                break;

            // Four refusals and four sentences, because they need four different things done
            // about them and one message covering all of them sends people to ask the wrong
            // question.
            case SCILicenseRedeemMalformed:
                [self say:SCIText(@"That is not a key or a code. Check what you pasted.",
                                  @"هذا ليس مفتاحاً ولا كوداً. تحقّق مما لصقته.")];
                break;
            case SCILicenseRedeemUnknown:
                [self say:SCIText(@"That code is not known. Check it, or ask for a new one.",
                                  @"هذا الكود غير معروف. تحقّق منه أو اطلب واحداً جديداً.")];
                break;
            case SCILicenseRedeemWindowClosed:
                [self say:SCIText(@"That code's redemption window has passed.",
                                  @"انتهت مهلة تفعيل هذا الكود.")];
                break;
            case SCILicenseRedeemTaken:
                [self say:SCIText(@"That code is already in use on another device.",
                                  @"هذا الكود مُستعمل على جهاز آخر.")];
                break;
            case SCILicenseRedeemOffline:
                [self say:SCIText(@"Nothing could be checked — the server was not reachable.",
                                  @"تعذّر التحقّق — لم يُوصل إلى الخادم.")];
                break;
        }
    });
}

- (void)sync {
    SCILicenseSyncWithServer(^(SCILicenseServerResult result) {
        [self refresh];

        // A failure to reach the server is reported as exactly that. It is never a licence
        // problem: a timeout or a captive portal must not read as "you are not licensed".
        if (result == SCILicenseServerOK) {
            [self say:SCIText(@"Up to date.", @"محدَّث.")];
        } else if (result == SCILicenseServerPending) {
            [self say:SCIText(@"Your request is waiting to be answered.",
                              @"طلبك بانتظار الردّ.")];
        } else if (result == SCILicenseServerUnreachable ||
                   result == SCILicenseServerNotConfigured) {
            [self say:SCIText(@"The server could not be reached. Nothing was decided.",
                              @"تعذّر الوصول إلى الخادم. لم يتقرّر شيء.")];
        } else {
            [self say:SCILicenseStatusLine()];
        }
    });
}

- (void)remove {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:SCIText(@"Remove the key?", @"إزالة المفتاح؟")
                                            message:SCIText(@"The tweak stops working until another licence is entered.",
                                                            @"تتوقّف الأداة حتى يُدخَل ترخيص آخر.")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [sheet addAction:[UIAlertAction actionWithTitle:SCIText(@"Cancel", @"إلغاء")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [sheet addAction:[UIAlertAction actionWithTitle:SCIText(@"Remove", @"إزالة")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        SCILicenseForgetKey();
        SCILicenseForgetCode();
        [self refresh];
    }]];

    [self presentViewController:sheet animated:YES completion:nil];
}

@end


@implementation SCILicenseUI

+ (void)presentFrom:(UIViewController *)host {
    if (!host) return;

    // Provisioned here as well as in the panel: on a device with no panel this is the first and
    // only moment anything asks for an identity, and a screen that shows "not created yet" and
    // then cannot copy anything is a screen that reads as broken.
    SCILicenseProvisionDevice();

    SCILicenseUIController *screen = [[SCILicenseUIController alloc] init];
    UINavigationController *wrapper =
        [[UINavigationController alloc] initWithRootViewController:screen];
    wrapper.modalPresentationStyle = UIModalPresentationFormSheet;

    // From whatever is actually on top. Presenting from underneath something already presented is
    // the single most common way a sheet silently never appears.
    UIViewController *top = host;
    while (top.presentedViewController) top = top.presentedViewController;

    [top presentViewController:wrapper animated:YES completion:nil];
}

+ (NSString *)summary {
    return SCILicenseStatusLine();
}

@end
