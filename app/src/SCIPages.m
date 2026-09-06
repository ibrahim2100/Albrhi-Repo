//
//  SCIPages.m
//  Albrhi Licences — the six screens.
//
//  In one file on purpose: each is forty lines of "fetch this, show these rows, act on a tap", and
//  six files of that would be six copies of the same three methods with different nouns. The base
//  class holds everything they share; what is left here is only what makes each one itself.
//

#import "SCIPage.h"
#import "SCIAPI.h"
#import "SCIPages.h"

#pragma mark - Requests

@implementation SCIRequestsPage {
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"الطلبات";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        id rows = state[@"requests"];
        self->_rows = [rows isKindOfClass:[NSArray class]] ? rows : @[];
        [self loaded];

        [self badge:self->_rows.count
            ? [NSString stringWithFormat:@"%lu", (unsigned long)self->_rows.count] : nil];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }

- (NSString *)emptyMessage {
    return @"لا طلبات تنتظر.\nتصل هنا وحدها حين يطلب أحدهم ترخيصاً من جهازه.";
}

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *request = _rows[(NSUInteger)row];

    NSString *who = request[@"name"] ?: request[@"note"] ?: @"—";
    NSString *contact = request[@"contact"] ?: @"";
    NSNumber *days = request[@"days"];
    BOOL lifetime = [request[@"lifetime"] boolValue];

    cell.textLabel.text = who;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@\n%@",
        SCIRun(request[@"key"] ?: @"?"),
        contact.length ? [@"  ·  " stringByAppendingString:SCIRun(contact)] : @"",
        lifetime ? @"مدى الحياة" : [NSString stringWithFormat:@"%@ يوماً", days ?: @365]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tapped:(NSInteger)row {
    NSDictionary *request = _rows[(NSUInteger)row];
    NSString *device = request[@"key"] ?: @"";

    // What the panel does on approval, and in the same words: the request's own name and number
    // travel into the licence rather than being flattened into a note nobody can search.
    NSDictionary *carried = @{
        @"dev": device,
        @"name": request[@"name"] ?: @"",
        @"contact": request[@"contact"] ?: @"",
        @"note": request[@"note"] ?: @"",
    };

    __weak typeof(self) weakSelf = self;
    void (^approve)(NSDictionary *) = ^(NSDictionary *terms) {
        NSMutableDictionary *body = [carried mutableCopy];
        [body addEntriesFromDictionary:terms];

        [SCIAPI call:@"/admin/approve" body:body then:^(NSDictionary *answer, NSString *error) {
            if (error) { [weakSelf failed:error]; return; }
            [weakSelf say:@"تمّت الموافقة"];
            [weakSelf reload];
        }];
    };

    // Shortest term first, longest last, and refusal at the bottom away from all of them.
    [self sheetTitled:request[@"name"] ?: device
              message:@"كم تمنحه؟"
              choices:@[
        [SCIChoice titled:@"شهر" does:^{ approve(@{@"mode": @"set", @"days": @30}); }],
        [SCIChoice titled:@"ستّة أشهر" does:^{ approve(@{@"mode": @"set", @"days": @180}); }],
        [SCIChoice titled:@"سنة" does:^{ approve(@{@"mode": @"set", @"days": @365}); }],
        [SCIChoice titled:@"مدى الحياة" does:^{ approve(@{@"mode": @"lifetime"}); }],
        [SCIChoice dangerous:@"رفض" does:^{
            [SCIAPI call:@"/admin/decline" body:@{@"dev": device}
                    then:^(NSDictionary *answer, NSString *error) {
                if (error) { [weakSelf failed:error]; return; }
                [weakSelf reload];
            }];
        }],
    ]];
}

@end


#pragma mark - Licences

@implementation SCILicencesPage {
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"التراخيص";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Codes live here rather than on a tab of their own: a code is a licence nobody has redeemed
    // yet, and the bar holds five tabs before it starts hiding things in a "More" list.
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"الأكواد"
                                          style:UIBarButtonItemStylePlain
                                         target:self
                                         action:@selector(showCodes)];
}

/// Live means: not withdrawn, and either without an end date or with one still ahead.
///
/// One function, because three places compare this field and the panel shipped "0 valid of 3"
/// when only one of them had been taught that zero means lifetime.
static BOOL SCIIsLive(NSDictionary *licence) {
    if ([licence[@"revoked"] boolValue]) return NO;

    double until = [licence[@"until"] doubleValue];
    return until == 0 || until > [NSDate date].timeIntervalSince1970;
}

- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        id rows = state[@"licences"];
        NSArray *all = [rows isKindOfClass:[NSArray class]] ? rows : @[];

        // Lifetime first, then by end date, newest first. Sorted by the term rather than by the
        // raw field: zero sorts below every date and would put the best licences at the bottom.
        self->_rows = [all sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,
                                                                         NSDictionary *b) {
            double first = [a[@"until"] doubleValue] == 0 ? DBL_MAX : [a[@"until"] doubleValue];
            double second = [b[@"until"] doubleValue] == 0 ? DBL_MAX : [b[@"until"] doubleValue];
            return second > first ? NSOrderedDescending : (second < first ? NSOrderedAscending
                                                                          : NSOrderedSame);
        }];
        [self loaded];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }
- (NSString *)emptyMessage { return @"لا تراخيص بعد."; }

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *licence = _rows[(NSUInteger)row];
    BOOL live = SCIIsLive(licence);

    cell.textLabel.text = licence[@"name"] ?: licence[@"note"] ?: licence[@"key"];
    cell.textLabel.textColor = live ? [UIColor labelColor] : [UIColor secondaryLabelColor];

    NSString *scope = SCIScopeName(licence[@"tier"]);
    NSString *state = [licence[@"revoked"] boolValue] ? @"مسحوب" : (live ? @"سارٍ" : @"منتهٍ");

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@  ·  %@\n%@",
        state, SCIRun(scope), SCIRun([SCIPage dateFrom:licence[@"until"]]),
        SCIRun(licence[@"key"] ?: @"")];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tapped:(NSInteger)row {
    NSDictionary *licence = _rows[(NSUInteger)row];
    NSString *device = licence[@"key"] ?: @"";
    __weak typeof(self) weakSelf = self;

    void (^change)(NSDictionary *) = ^(NSDictionary *terms) {
        NSMutableDictionary *body = [@{@"dev": device} mutableCopy];
        [body addEntriesFromDictionary:terms];

        [SCIAPI call:@"/admin/approve" body:body then:^(NSDictionary *answer, NSString *error) {
            if (error) { [weakSelf failed:error]; return; }
            [weakSelf reload];
        }];
    };

    NSMutableArray<SCIChoice *> *choices = [@[
        [SCIChoice titled:@"تفاصيل" does:^{ [weakSelf showDetail:licence]; }],
        [SCIChoice titled:@"مدّد ٣٠ يوماً" does:^{ change(@{@"mode": @"extend", @"days": @30}); }],
        [SCIChoice titled:@"مدّد سنة" does:^{ change(@{@"mode": @"extend", @"days": @365}); }],
        [SCIChoice titled:@"اجعله مدى الحياة" does:^{ change(@{@"mode": @"lifetime"}); }],
    ] mutableCopy];

    // Withdrawing is the last row and the only red one; restoring is neither, because putting a
    // licence back is not a thing anybody needs warning about.
    if ([licence[@"revoked"] boolValue]) {
        [choices addObject:[SCIChoice titled:@"إرجاع" does:^{
            [SCIAPI call:@"/admin/restore" body:@{@"dev": device}
                    then:^(NSDictionary *answer, NSString *error) { [weakSelf reload]; }];
        }]];
    } else {
        [choices addObject:[SCIChoice dangerous:@"سحب" does:^{
            [SCIAPI call:@"/admin/revoke" body:@{@"dev": device}
                    then:^(NSDictionary *answer, NSString *error) { [weakSelf reload]; }];
        }]];
    }

    [self sheetTitled:licence[@"name"] ?: device message:nil choices:choices];
}

/// Everything known about one licence, including which apps it is running in.
///
/// A row cannot answer the question that actually gets asked -- "it stopped working" needs the
/// apps and their versions, and those come from the devices themselves on every check-in.
- (void)showDetail:(NSDictionary *)licence {
    NSMutableString *text = [NSMutableString string];

    [text appendFormat:@"الجهاز: %@\n", licence[@"key"] ?: @"?"];
    if ([licence[@"contact"] length]) [text appendFormat:@"الجوال: %@\n", licence[@"contact"]];
    [text appendFormat:@"يغطّي: %@\n", SCIScopeName(licence[@"tier"])];
    [text appendFormat:@"المدّة: %@\n", [SCIPage dateFrom:licence[@"until"]]];
    if ([licence[@"codeText"] length]) [text appendFormat:@"الكود: %@\n", licence[@"codeText"]];

    NSDictionary *installs = licence[@"installs"];
    [text appendString:@"\nالأدوات:\n"];

    if ([installs isKindOfClass:[NSDictionary class]] && installs.count) {
        for (NSString *product in installs) {
            NSDictionary *seen = installs[product];
            [text appendFormat:@"  %@ %@ · %@\n", SCIRun(product),
                SCIRun(seen[@"version"] ?: @"?"), SCIRun([SCIPage dateFrom:seen[@"at"]])];
        }
    } else {
        [text appendString:@"  لا شيء بعد — تُسجَّل عند أوّل مزامنة.\n"];
    }

    UIAlertController *detail =
        [UIAlertController alertControllerWithTitle:licence[@"name"] ?: @"ترخيص"
                                            message:text
                                     preferredStyle:UIAlertControllerStyleAlert];
    [detail addAction:[UIAlertAction actionWithTitle:@"إغلاق"
                                               style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:detail animated:YES completion:nil];
}

- (void)showCodes {
    [self.navigationController pushViewController:[[SCICodesPage alloc] init] animated:YES];
}

@end


#pragma mark - Devices

@implementation SCIDevicesPage {
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"الأجهزة";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

/// Both sources, because a store activation names a device with no licence at all and a page
/// showing only licences would be missing exactly the people a store copy was sold to.
- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *licence in state[@"licences"] ?: @[]) {
            NSDictionary *installs = licence[@"installs"];
            NSString *who = licence[@"name"] ?: SCIScopeName(licence[@"tier"]);

            if (![installs isKindOfClass:[NSDictionary class]] || !installs.count) {
                [rows addObject:@{@"dev": licence[@"key"] ?: @"?", @"who": who,
                                  @"what": @"—", @"at": @0}];
                continue;
            }
            for (NSString *product in installs) {
                NSDictionary *seen = installs[product];
                [rows addObject:@{@"dev": licence[@"key"] ?: @"?", @"who": who,
                                  @"what": [NSString stringWithFormat:@"%@ %@", product,
                                            seen[@"version"] ?: @""],
                                  @"at": seen[@"at"] ?: @0}];
            }
        }

        [SCIAPI stores:^(NSArray *stores, NSString *storeError) {
            for (NSDictionary *store in stores ?: @[]) {
                for (NSDictionary *seen in store[@"sample"] ?: @[]) {
                    [rows addObject:@{@"dev": seen[@"dev"] ?: @"?",
                                      @"who": store[@"name"] ?: store[@"id"] ?: @"متجر",
                                      @"what": [NSString stringWithFormat:@"%@ %@",
                                                seen[@"product"] ?: @"—", seen[@"version"] ?: @""],
                                      @"at": seen[@"last"] ?: @0}];
                }
            }

            [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [b[@"at"] compare:a[@"at"]];
            }];

            self->_rows = rows;
            [self loaded];
        }];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }
- (NSString *)emptyMessage { return @"لا أجهزة معروفة بعد."; }

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *device = _rows[(NSUInteger)row];
    cell.textLabel.text = device[@"who"];

    // **Not +dateFrom: here.** Zero means "no end" in a licence's term and "never seen" in a last
    // seen, and printing ∞ for the second says a device that has never once reported in is
    // reporting in forever.
    double at = [device[@"at"] doubleValue];
    NSString *when = at > 0 ? [SCIPage dateFrom:device[@"at"]] : @"لم يُشاهد بعد";

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@  ·  %@",
        SCIRun(device[@"dev"]), SCIRun(device[@"what"]), SCIRun(when)];
}

@end


#pragma mark - Stores

@implementation SCIStoresPage {
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"المتاجر";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self action:@selector(add)];
}

- (void)fetch {
    [SCIAPI stores:^(NSArray *stores, NSString *error) {
        if (error) { [self failed:error]; return; }
        self->_rows = stores ?: @[];
        [self loaded];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }
- (NSString *)emptyMessage { return @"لا متاجر.\nأضف واحداً بعلامة +، وأعطِ المتجر كوده."; }

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *store = _rows[(NSUInteger)row];
    cell.textLabel.text = store[@"name"] ?: store[@"id"];

    // Two counts, because they answer different questions and only the second says whether
    // renewing is worth it.
    cell.detailTextLabel.text = [NSString stringWithFormat:
        @"الكود %@  ·  حتى %@\n%@ جهازاً · %@ نشِطاً هذا الأسبوع",
        SCIRun(store[@"code"] ?: store[@"id"]), SCIRun([SCIPage dateFrom:store[@"until"]]),
        store[@"devices"] ?: @0, store[@"recent"] ?: @0];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)add {
    __weak typeof(self) weakSelf = self;
    [self askTitled:@"متجر جديد" message:@"رمز المتجر، وهو الكود الذي يكتبه المشترك"
              value:nil keyboard:UIKeyboardTypeASCIICapable then:^(NSString *identifier) {
        if (!identifier.length) return;
        [SCIAPI call:@"/admin/store"
                body:@{@"id": identifier, @"code": identifier, @"name": identifier, @"days": @90}
                then:^(NSDictionary *answer, NSString *error) {
            if (error) { [weakSelf failed:error]; return; }
            [weakSelf reload];
        }];
    }];
}

- (void)tapped:(NSInteger)row {
    NSDictionary *store = _rows[(NSUInteger)row];
    NSString *identifier = store[@"id"] ?: @"";
    __weak typeof(self) weakSelf = self;

    void (^change)(NSDictionary *) = ^(NSDictionary *terms) {
        NSMutableDictionary *body = [@{@"id": identifier} mutableCopy];
        [body addEntriesFromDictionary:terms];
        [SCIAPI call:@"/admin/store" body:body then:^(NSDictionary *answer, NSString *error) {
            if (error) { [weakSelf failed:error]; return; }
            [weakSelf reload];
        }];
    };

    NSMutableArray<SCIChoice *> *choices = [@[
        [SCIChoice titled:@"جدّد ٩٠ يوماً" does:^{ change(@{@"days": @90}); }],
        [SCIChoice titled:@"جدّد سنة" does:^{ change(@{@"days": @365}); }],
        [SCIChoice titled:@"غيّر الاسم" does:^{
            [weakSelf askTitled:@"اسم المتجر" message:nil value:store[@"name"]
                       keyboard:UIKeyboardTypeDefault then:^(NSString *name) {
                change(@{@"name": name});
            }];
        }],
    ] mutableCopy];

    if ([store[@"revoked"] boolValue]) {
        [choices addObject:[SCIChoice titled:@"إرجاع" does:^{ change(@{@"revoked": @NO}); }]];
    } else {
        [choices addObject:[SCIChoice dangerous:@"سحب" does:^{ change(@{@"revoked": @YES}); }]];
    }

    [self sheetTitled:store[@"name"] ?: identifier
              message:[NSString stringWithFormat:@"%@ جهازاً · %@ نشِطاً هذا الأسبوع",
                       store[@"devices"] ?: @0, store[@"recent"] ?: @0]
              choices:choices];
}

@end


#pragma mark - Codes

@implementation SCICodesPage {
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    // Set here and not in -viewDidLoad: a tab bar asks its item for a title before the page's
    // view has ever been loaded, so a title assigned at load time leaves every tab the user
    // has not visited yet showing an icon and nothing else.
    if ((self = [super init])) self.title = @"الأكواد";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self action:@selector(mint)];
}

- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }
        id rows = state[@"codes"];
        self->_rows = [rows isKindOfClass:[NSArray class]] ? rows : @[];
        [self loaded];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }

- (NSString *)emptyMessage {
    return @"لا أكواد.\nالخادم يحفظ بصماتها فقط، فلا يمكن إظهار كودٍ مرّة ثانية.";
}

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *code = _rows[(NSUInteger)row];
    BOOL used = [code[@"dev"] isKindOfClass:[NSString class]] && [code[@"dev"] length];

    cell.textLabel.text = used ? @"مُستعمَل" : @"لم يُستعمَل بعد";
    cell.textLabel.textColor = used ? [UIColor secondaryLabelColor] : [UIColor labelColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ يوماً · %@\n%@",
        code[@"days"] ?: @0, SCIRun(SCIScopeName(code[@"tier"])),
        SCIRun(used ? code[@"dev"] : (code[@"note"] ?: @""))];
}

- (void)mint {
    __weak typeof(self) weakSelf = self;
    [self askTitled:@"كم كوداً؟" message:@"تُعرَض مرّةً واحدة، فانسخها فوراً"
              value:@"5" keyboard:UIKeyboardTypeNumberPad then:^(NSString *count) {
        [SCIAPI call:@"/admin/codes"
                body:@{@"count": @(count.integerValue ?: 1), @"days": @365, @"window": @90,
                       @"tier": @"suite"}
                then:^(NSDictionary *answer, NSString *error) {
            if (error) { [weakSelf failed:error]; return; }

            NSArray *codes = answer[@"codes"];
            NSString *text = [codes componentsJoinedByString:@"\n"];

            // Copied for them, not just shown: a code read off a screen and typed into a message
            // is a code with a typo in it.
            [UIPasteboard generalPasteboard].string = text;

            UIAlertController *shown =
                [UIAlertController alertControllerWithTitle:@"نُسخت"
                                                    message:text
                                             preferredStyle:UIAlertControllerStyleAlert];
            [shown addAction:[UIAlertAction actionWithTitle:@"تمام"
                                                      style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:shown animated:YES completion:nil];
            [weakSelf reload];
        }];
    }];
}

@end
