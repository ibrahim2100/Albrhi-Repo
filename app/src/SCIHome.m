//
//  SCIHome.m
//  Albrhi Licences — the front page, and the settings behind it.
//

#import "SCIPages.h"
#import "SCIAPI.h"
#import "SCINotify.h"
#import "SCIMessages.h"

#pragma mark - Summary

@implementation SCISummaryPage {
    NSArray<NSDictionary *> *_cards;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"الرئيسية";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // The gear, not a tab: settings are opened when something is wrong and never otherwise, which
    // is not worth one of the five slots the bar has.
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                          style:UIBarButtonItemStylePlain
                                         target:self
                                         action:@selector(showSettings)];
}

- (void)showSettings {
    [self.navigationController pushViewController:[[SCISettingsPage alloc] init] animated:YES];
}

/// Numbers worth acting on, not numbers worth having.
///
/// The one that earns its place is "ends within a fortnight": a licence about to lapse is a
/// conversation, and every day it is left is a day closer to being a complaint instead.
- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        NSArray *requests = [state[@"requests"] isKindOfClass:[NSArray class]]
            ? state[@"requests"] : @[];
        NSArray *licences = [state[@"licences"] isKindOfClass:[NSArray class]]
            ? state[@"licences"] : @[];
        NSArray *trials = [state[@"trials"] isKindOfClass:[NSArray class]] ? state[@"trials"] : @[];

        double now = [NSDate date].timeIntervalSince1970;
        NSUInteger live = 0, soon = 0, devices = 0;

        for (NSDictionary *licence in licences) {
            double until = [licence[@"until"] doubleValue];
            BOOL running = ![licence[@"revoked"] boolValue] && (until == 0 || until > now);
            if (!running) continue;

            live++;
            if (until > 0 && until < now + 14 * 86400) soon++;

            NSDictionary *installs = licence[@"installs"];
            devices += [installs isKindOfClass:[NSDictionary class]] ? installs.count : 0;
        }

        [SCIAPI stores:^(NSArray *stores, NSString *storeError) {
            NSUInteger storeDevices = 0;
            for (NSDictionary *store in stores ?: @[]) {
                storeDevices += [store[@"recent"] unsignedIntegerValue];
            }

            self->_cards = @[
                @{@"n": @(requests.count), @"t": @"طلب ينتظر", @"tab": @1},
                @{@"n": @(live),           @"t": @"ترخيص سارٍ", @"tab": @2, @"scope": @1},
                @{@"n": @(soon),           @"t": @"ينتهي خلال أسبوعين", @"tab": @2, @"scope": @2},
                @{@"n": @(devices),        @"t": @"جهازاً بترخيص", @"tab": @3},
                @{@"n": @(storeDevices),   @"t": @"جهاز متجر نشِطاً هذا الأسبوع", @"tab": @4},
                @{@"n": @(trials.count),   @"t": @"أسبوعاً مجانياً مُنح"},
            ];
            [self loaded];
        }];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_cards.count; }

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *card = _cards[(NSUInteger)row];

    cell.textLabel.text = [card[@"n"] stringValue];
    cell.textLabel.font = [UIFont monospacedDigitSystemFontOfSize:34
                                                            weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = card[@"t"];

    // The one that needs doing something about is the only one coloured. A dashboard where every
    // number is red is a dashboard nobody reads.
    BOOL urgent = (row == 0 || row == 2) && [card[@"n"] integerValue] > 0;
    cell.textLabel.textColor = urgent ? [UIColor systemOrangeColor] : [UIColor labelColor];

    // A number worth acting on has somewhere to go. «Ends within a fortnight: 1» that cannot be
    // tapped is the most important line on the screen and a dead end.
    cell.accessoryType = card[@"tab"] ? UITableViewCellAccessoryDisclosureIndicator
                                      : UITableViewCellAccessoryNone;
}

- (void)tapped:(NSInteger)row {
    NSDictionary *card = _cards[(NSUInteger)row];
    NSNumber *tab = card[@"tab"];
    if (!tab) return;

    SCIPage *page = [self showTab:tab.integerValue];

    // The filter the card was counting with, so the list that opens holds exactly those rows and
    // not a longer list the reader has to narrow again by hand.
    NSNumber *scope = card[@"scope"];
    if (scope && [page respondsToSelector:@selector(applyScope:)]) {
        [(id)page applyScope:scope.integerValue];
    }
}

@end


#pragma mark - Settings

@implementation SCISettingsPage {
    NSArray<NSString *> *_rows;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"الإعدادات";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _rows = @[@"عنوان الخادم", @"رمز الإدارة", @"الإشعارات", @"رسائل واتساب",
              @"جرّب الاتّصال", @"عن التطبيق"];
}

- (void)fetch { [self loaded]; }
- (NSInteger)rowCount { return (NSInteger)_rows.count; }

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    cell.textLabel.text = _rows[(NSUInteger)row];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    switch (row) {
        case 0:
            // Which of the two it is, named. «The built-in one» and «one I chose» are different
            // facts, and only the second is worth suspecting when something stops working.
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@",
                [SCIAPI baseIsMine] ? @"اخترته" : @"المدمج", SCIRun([SCIAPI base])];
            break;
        case 1:
            // Never the token itself, not even partly. A screen that shows a secret is a screen
            // that shows it to whoever is standing behind you, and there is nothing to be learned
            // from seeing it that "set" does not already say.
            cell.detailTextLabel.text = [SCIAPI token].length ? @"محفوظ في الـKeychain"
                                                              : @"غير مضبوط";
            break;
        case 2:
            cell.detailTextLabel.text = [SCINotify isOn]
                ? @"تصلك إشعارات عند وصول طلب جديد" : @"مطفأة";
            break;
        case 3: {
            NSUInteger edited = 0;
            for (NSInteger kind = 0; kind < SCIMessageCount; kind++) {
                if ([SCIMessages isEdited:(SCIMessageKind)kind]) edited++;
            }
            cell.detailTextLabel.text = edited
                ? [NSString stringWithFormat:@"%lu معدّلة من %d", (unsigned long)edited,
                   (int)SCIMessageCount]
                : @"النصوص الأصلية";
            break;
        }
        case 4:
            cell.detailTextLabel.text = @"يسأل الخادم ويقول ما جاء";
            break;
        default:
            cell.detailTextLabel.text = @"تراخيص البرهي · لوحة التحكّم";
            break;
    }
}

- (void)tapped:(NSInteger)row {
    __weak typeof(self) weakSelf = self;

    switch (row) {
        case 0: {
            [self askTitled:@"عنوان الخادم"
                    message:@"اتركه فارغاً للعودة إلى العنوان المدمج. https فقط — ترخيصٌ عبر http "
                             "يمكن تبديله في الطريق"
                      value:[SCIAPI baseIsMine] ? [SCIAPI base] : @""
                   keyboard:UIKeyboardTypeURL then:^(NSString *base) {
                // Empty clears, which is the only way back to the built-in address once one has
                // been typed — the same absent-keeps/empty-clears rule the server itself follows.
                if (base.length && ![base hasPrefix:@"https://"]) {
                    [weakSelf say:@"لا بدّ من https"];
                    return;
                }
                [SCIAPI setBase:base];
                [weakSelf reload];
            }];
            break;
        }

        case 1: {
            [self askTitled:@"رمز الإدارة"
                    message:@"يُحفظ في الـKeychain، ولا يظهر بعدها"
                      value:nil keyboard:UIKeyboardTypeASCIICapable then:^(NSString *token) {
                [SCIAPI setToken:token];
                [weakSelf reload];
            }];
            break;
        }

        case 2: {
            [SCINotify toggle:^(BOOL on, NSString *why) {
                if (why) [weakSelf say:why];
                [weakSelf reload];
            }];
            break;
        }

        case 3: {
            [self.navigationController pushViewController:[[SCIMessagesPage alloc] init]
                                                 animated:YES];
            break;
        }

        case 4: {
            [SCIAPI state:^(NSDictionary *state, NSString *error) {
                if (error) { [weakSelf say:error]; return; }
                NSArray *licences = state[@"licences"];
                [weakSelf say:[NSString stringWithFormat:@"متّصل · %lu ترخيصاً",
                               (unsigned long)[licences count]]];
            }];
            break;
        }

        default:
            break;
    }
}

@end
