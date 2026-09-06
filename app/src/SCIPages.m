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
#import "SCIMessages.h"
#import "SCIPages.h"

#pragma mark - Requests

@implementation SCIRequestsPage {
    NSArray<NSDictionary *> *_all;
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
    [self searchableWith:@"اسم، رقم جوال، أو رمز جهاز"];
}

- (void)queryChanged {
    NSMutableArray *kept = [NSMutableArray array];
    for (NSDictionary *request in _all) {
        if ([self matches:@[request[@"name"] ?: @"", request[@"contact"] ?: @"",
                            request[@"key"] ?: @"", request[@"note"] ?: @""]]) {
            [kept addObject:request];
        }
    }
    _rows = kept;
}

- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        id rows = state[@"requests"];
        self->_all = [rows isKindOfClass:[NSArray class]] ? rows : @[];
        [self queryChanged];
        [self loaded];

        // The badge counts what is waiting, never what the search left of it: a filtered list is
        // a question being asked, not a change in how many people are waiting for an answer.
        [self badge:self->_all.count
            ? [NSString stringWithFormat:@"%lu", (unsigned long)self->_all.count] : nil];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }

- (NSString *)emptyMessage {
    return @"لا طلبات تنتظر.\nتصل هنا وحدها حين يطلب أحدهم ترخيصاً من جهازه.";
}

- (NSArray<SCIChoice *> *)swipeActionsAt:(NSInteger)row {
    NSDictionary *request = _rows[(NSUInteger)row];
    NSString *device = request[@"key"] ?: @"";
    __weak typeof(self) weakSelf = self;

    return @[
        [SCIChoice dangerous:@"رفض" does:^{
            // Refusing deletes the request, and with it the name and the number. There is no
            // undo on the server's side, which is exactly why there is one here.
            [weakSelf afterUndo:@"رُفض الطلب" does:^{
                [SCIAPI call:@"/admin/decline" body:@{@"dev": device}
                        then:^(NSDictionary *answer, NSString *error) {
                    if (error) { [weakSelf failed:error]; return; }
                    [weakSelf reload];
                }];
            }];
        }],
        [SCIChoice titled:@"سنة" does:^{
            NSDictionary *body = @{@"dev": device, @"mode": @"set", @"days": @365,
                                   @"name": request[@"name"] ?: @"",
                                   @"contact": request[@"contact"] ?: @""};
            [SCIAPI call:@"/admin/approve" body:body
                    then:^(NSDictionary *answer, NSString *error) {
                if (error) { [weakSelf failed:error]; return; }
                [weakSelf say:@"تمّت الموافقة — سنة"];
                [weakSelf reload];
            }];
        }],
    ];
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
        [SCIChoice titled:@"انسخ رمز الجهاز" does:^{ [weakSelf copyText:device]; }],
        [SCIChoice titled:@"واتساب" does:^{
            if (![weakSelf whatsApp:request[@"contact"]
                             saying:[SCIMessages fill:SCIMessageRequest with:request]]) {
                [weakSelf say:@"لا رقم في هذا الطلب"];
            }
        }],
        [SCIChoice dangerous:@"رفض" does:^{
            // Refusing deletes the request, and with it the name and the number. There is no
            // undo on the server's side, which is exactly why there is one here.
            [weakSelf afterUndo:@"رُفض الطلب" does:^{
                [SCIAPI call:@"/admin/decline" body:@{@"dev": device}
                        then:^(NSDictionary *answer, NSString *error) {
                    if (error) { [weakSelf failed:error]; return; }
                    [weakSelf reload];
                }];
            }];
        }],
    ]];
}

@end


#pragma mark - Licences

/// Every scope the server accepts, in the order the panel offers them.
///
/// **One list, because three places used to keep their own.** The panel shipped with a scope
/// picker in two of the three cards that set one, so the single route that mints a licence by
/// hand could not mint an app-scoped licence at all — which is exactly the licence somebody
/// buying one tweak needs.
static NSArray<NSArray<NSString *> *> *SCIScopes(void) {
    return @[
        @[@"suite",         @"الحزمة كاملة (جيلبريك)"],
        @[@"apps",          @"كل الأدوات المنفصلة"],
        @[@"app:instagram", @"إنستغرام وحدها"],
        @[@"app:youtube",   @"يوتيوب وحدها"],
        @[@"app:twitter",   @"X وحدها"],
        @[@"app:tiktok",    @"تيك توك وحدها"],
        @[@"trial",         @"تجربة"],
    ];
}

@implementation SCILicencesPage {
    NSArray<NSDictionary *> *_all;      // everything the server has
    NSArray<NSDictionary *> *_rows;     // what the search leaves of it
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
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"الأكواد"
                                          style:UIBarButtonItemStylePlain
                                         target:self
                                         action:@selector(showCodes)];

    // Issuing by hand, for a device whose code you were given without a request being sent.
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self action:@selector(issue)];

    [self searchableWith:@"اسم، رقم جوال، رمز جهاز، أو كود"
                  scopes:@[@"الكل", @"سارٍ", @"قريب", @"منتهٍ", @"مسحوب"]];
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
        self->_all = [all sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,
                                                                         NSDictionary *b) {
            double first = [a[@"until"] doubleValue] == 0 ? DBL_MAX : [a[@"until"] doubleValue];
            double second = [b[@"until"] doubleValue] == 0 ? DBL_MAX : [b[@"until"] doubleValue];
            return second > first ? NSOrderedDescending : (second < first ? NSOrderedAscending
                                                                          : NSOrderedSame);
        }];
        [self queryChanged];
        [self loaded];
    }];
}

/// The filter and the search are one pass, and the filter is asked first because it is cheaper.
- (BOOL)passesFilter:(NSDictionary *)licence {
    double until = [licence[@"until"] doubleValue];
    double now = [NSDate date].timeIntervalSince1970;
    BOOL revoked = [licence[@"revoked"] boolValue];
    BOOL live = SCIIsLive(licence);

    switch (self.scope) {
        case 1: return live;
        case 2: return live && until > 0 && until < now + 14 * 86400;   // ends within a fortnight
        case 3: return !live && !revoked;
        case 4: return revoked;
        default: return YES;
    }
}

- (void)queryChanged {
    NSMutableArray *kept = [NSMutableArray array];
    for (NSDictionary *licence in _all) {
        if (![self passesFilter:licence]) continue;

        if ([self matches:@[licence[@"name"] ?: @"", licence[@"contact"] ?: @"",
                            licence[@"key"] ?: @"", licence[@"codeText"] ?: @"",
                            licence[@"note"] ?: @""]]) {
            [kept addObject:licence];
        }
    }
    _rows = kept;
}

/// A swipe offers the two things done most often, and the same blocks the sheet uses.
- (NSArray<SCIChoice *> *)swipeActionsAt:(NSInteger)row {
    NSDictionary *licence = _rows[(NSUInteger)row];
    NSString *device = licence[@"key"] ?: @"";
    __weak typeof(self) weakSelf = self;

    NSMutableArray<SCIChoice *> *actions = [NSMutableArray array];

    if ([licence[@"contact"] length]) {
        [actions addObject:[SCIChoice titled:@"واتساب" does:^{
            SCIMessageKind kind = SCIIsLive(licence) ? SCIMessageRenewal : SCIMessageExpired;
            [weakSelf whatsApp:licence[@"contact"] saying:[SCIMessages fill:kind with:licence]];
        }]];
    }

    [actions addObject:[SCIChoice titled:@"سنة" does:^{
        [SCIAPI call:@"/admin/approve"
                body:@{@"dev": device, @"mode": @"extend", @"days": @365}
                then:^(NSDictionary *answer, NSString *error) {
            if (error) { [weakSelf failed:error]; return; }
            [weakSelf say:@"مُدّد سنة"];
            [weakSelf reload];
        }];
    }]];

    return actions;
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

    // **Absent keeps, empty clears** — the server's own rule, so a field must be sent only when
    // it is being changed. Sending @"" for everything untouched would wipe a name on every edit.
    NSMutableArray<SCIChoice *> *choices = [@[
        [SCIChoice titled:@"تفاصيل" does:^{ [weakSelf showDetail:licence]; }],
        [SCIChoice titled:@"انسخ رمز الجهاز" does:^{ [weakSelf copyText:device]; }],
        [SCIChoice titled:@"مدّد ٣٠ يوماً" does:^{ change(@{@"mode": @"extend", @"days": @30}); }],
        [SCIChoice titled:@"مدّد سنة" does:^{ change(@{@"mode": @"extend", @"days": @365}); }],
        [SCIChoice titled:@"مدّة أخرى…" does:^{
            [weakSelf askTitled:@"كم يوماً تُضاف؟"
                        message:@"تُضاف إلى ما تبقّى، لا تُبدّله. رقم سالب يُقصّر."
                          value:@"" keyboard:UIKeyboardTypeNumbersAndPunctuation
                           then:^(NSString *days) {
                if (!days.length) return;
                change(@{@"mode": @"extend", @"days": @(days.integerValue)});
            }];
        }],
        [SCIChoice titled:@"اجعله مدى الحياة" does:^{ change(@{@"mode": @"lifetime"}); }],
        [SCIChoice titled:@"غيّر الاسم" does:^{
            [weakSelf askTitled:@"الاسم" message:@"اتركه فارغاً لمسحه"
                          value:licence[@"name"] keyboard:UIKeyboardTypeDefault
                           then:^(NSString *name) { change(@{@"name": name}); }];
        }],
        [SCIChoice titled:@"غيّر الجوال" does:^{
            [weakSelf askTitled:@"الجوال" message:@"اتركه فارغاً لمسحه"
                          value:licence[@"contact"] keyboard:UIKeyboardTypePhonePad
                           then:^(NSString *contact) { change(@{@"contact": contact}); }];
        }],
        [SCIChoice titled:@"غيّر ما يغطّيه" does:^{ [weakSelf pickScope:^(NSString *tier) {
            change(@{@"tier": tier});
        }]; }],
    ] mutableCopy];

    // Only when there is a number to open it with: a row that cannot do anything is not drawn.
    if ([licence[@"contact"] length]) {
        [choices addObject:[SCIChoice titled:@"واتساب" does:^{
            // Which of the three it is follows from the licence rather than from a choice: a
            // renewal reminder sent to somebody whose licence lapsed last month reads as a shop
            // that does not know its own customers.
            SCIMessageKind kind = !SCIIsLive(licence) ? SCIMessageExpired
                : ([licence[@"until"] doubleValue] > 0 &&
                   [licence[@"until"] doubleValue] < [NSDate date].timeIntervalSince1970
                       + 14 * 86400) ? SCIMessageRenewal : SCIMessageWelcome;

            if (![weakSelf whatsApp:licence[@"contact"]
                             saying:[SCIMessages fill:kind with:licence]]) {
                [weakSelf say:@"لا رقم صالح في هذا الترخيص"];
            }
        }]];
    }

    // Withdrawing is the last row and the only red one; restoring is neither, because putting a
    // licence back is not a thing anybody needs warning about.
    if ([licence[@"revoked"] boolValue]) {
        [choices addObject:[SCIChoice titled:@"إرجاع" does:^{
            [SCIAPI call:@"/admin/restore" body:@{@"dev": device}
                    then:^(NSDictionary *answer, NSString *error) { [weakSelf reload]; }];
        }]];
    } else {
        [choices addObject:[SCIChoice dangerous:@"سحب" does:^{
            [weakSelf afterUndo:@"سُحب الترخيص" does:^{
                [SCIAPI call:@"/admin/revoke" body:@{@"dev": device}
                        then:^(NSDictionary *answer, NSString *error) { [weakSelf reload]; }];
            }];
        }]];
    }

    // Withdrawing keeps the record; deleting does not. Two different acts — "was this taken away
    // or did I never issue it" is answerable six months later only if the first keeps its row.
    [choices addObject:[SCIChoice dangerous:@"احذفه نهائياً" does:^{
        [weakSelf sheetTitled:@"حذف الترخيص" message:@"لا رجعة فيه. «سحب» يوقفه ويُبقي سجلّه."
                      choices:@[[SCIChoice dangerous:@"احذف" does:^{
            [weakSelf afterUndo:@"حُذف الترخيص" does:^{
                [SCIAPI call:@"/admin/delete" body:@{@"dev": device}
                        then:^(NSDictionary *answer, NSString *error) {
                    if (error) { [weakSelf failed:error]; return; }
                    [weakSelf reload];
                }];
            }];
        }]]];
    }]];

    [self sheetTitled:licence[@"name"] ?: device
              message:[NSString stringWithFormat:@"%@  ·  %@",
                       SCIRun(device), SCIScopeName(licence[@"tier"])]
              choices:choices];
}

/// One picker for every place that sets a scope.
- (void)pickScope:(void (^)(NSString *tier))then {
    NSMutableArray<SCIChoice *> *choices = [NSMutableArray array];
    for (NSArray<NSString *> *scope in SCIScopes()) {
        [choices addObject:[SCIChoice titled:scope[1] does:^{ then(scope[0]); }]];
    }
    [self sheetTitled:@"ما الذي يغطّيه؟" message:nil choices:choices];
}

/// A licence for a device that never sent a request.
///
/// The device code is asked for first because it is the one thing that can be wrong in a way
/// nothing later can fix: sixteen hex characters, checked here rather than by the server's
/// refusal.
- (void)issue {
    __weak typeof(self) weakSelf = self;

    [self askTitled:@"إصدار مباشر"
            message:@"رمز الجهاز كما يظهر في صفحة الترخيص عنده"
              value:@"" keyboard:UIKeyboardTypeASCIICapable then:^(NSString *typed) {

        NSString *device = [[typed stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

        NSCharacterSet *notHex = [[NSCharacterSet characterSetWithCharactersInString:
            @"0123456789abcdef"] invertedSet];

        if (device.length < 8 ||
            [device rangeOfCharacterFromSet:notHex].location != NSNotFound) {
            [weakSelf say:@"رمز الجهاز غير صالح"];
            return;
        }

        [weakSelf pickScope:^(NSString *tier) {
            [weakSelf askTitled:@"لمن" message:@"اسم أو ملاحظة — يظهر في القائمة"
                          value:@"" keyboard:UIKeyboardTypeDefault then:^(NSString *name) {

                void (^grant)(NSDictionary *) = ^(NSDictionary *term) {
                    NSMutableDictionary *body = [@{@"dev": device, @"tier": tier,
                                                   @"name": name ?: @""} mutableCopy];
                    [body addEntriesFromDictionary:term];

                    [SCIAPI call:@"/admin/approve" body:body
                            then:^(NSDictionary *answer, NSString *error) {
                        if (error) { [weakSelf failed:error]; return; }
                        [weakSelf say:@"صدر الترخيص"];
                        [weakSelf reload];
                    }];
                };

                [weakSelf sheetTitled:@"المدّة" message:nil choices:@[
                    [SCIChoice titled:@"أسبوع" does:^{ grant(@{@"mode": @"set", @"days": @7}); }],
                    [SCIChoice titled:@"شهر" does:^{ grant(@{@"mode": @"set", @"days": @30}); }],
                    [SCIChoice titled:@"ستّة أشهر" does:^{ grant(@{@"mode": @"set", @"days": @180}); }],
                    [SCIChoice titled:@"سنة" does:^{ grant(@{@"mode": @"set", @"days": @365}); }],
                    [SCIChoice titled:@"مدى الحياة" does:^{ grant(@{@"mode": @"lifetime"}); }],
                ]];
            }];
        }];
    }];
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

    // **The ledger was already being kept and never shown.** The server stores the last ten
    // changes to every licence, which is the answer to "when was this extended, and by how much"
    // — asked constantly and, until now, answerable only from memory.
    NSArray *history = licence[@"history"];
    if ([history isKindOfClass:[NSArray class]] && history.count) {
        [text appendString:@"\nما جرى:\n"];

        for (NSDictionary *entry in [history reverseObjectEnumerator]) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;

            double became = [entry[@"until"] doubleValue];
            NSString *what = [entry[@"mode"] isEqualToString:@"lifetime"]
                ? @"صار مدى الحياة"
                : [NSString stringWithFormat:@"حتى %@",
                   became > 0 ? [SCIPage dateFrom:entry[@"until"]] : @"∞"];

            [text appendFormat:@"  %@ · %@\n",
                SCIRun([SCIPage dateFrom:entry[@"at"]]), SCIRun(what)];
        }
    }

    UIAlertController *detail =
        [UIAlertController alertControllerWithTitle:licence[@"name"] ?: @"ترخيص"
                                            message:text
                                     preferredStyle:UIAlertControllerStyleAlert];
    [detail addAction:[UIAlertAction actionWithTitle:@"إغلاق"
                                               style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:detail animated:YES completion:nil];
}

- (void)applyScope:(NSInteger)scope {
    // The view has to exist before its search bar can be moved, and a tab's page is not built
    // until it is shown — which it has been, by the time this is called.
    [self loadViewIfNeeded];
    [self selectScope:scope];
}

- (void)showCodes {
    [self.navigationController pushViewController:[[SCICodesPage alloc] init] animated:YES];
}

@end


#pragma mark - Devices

@implementation SCIDevicesPage {
    NSArray<NSDictionary *> *_all;
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
    [self searchableWith:@"اسم، أو رمز جهاز"];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"الأسابيع المجانية"
                                          style:UIBarButtonItemStylePlain
                                         target:self action:@selector(showTrials)];
}

- (void)showTrials {
    [self.navigationController pushViewController:[[SCITrialsPage alloc] init] animated:YES];
}

- (void)queryChanged {
    NSMutableArray *kept = [NSMutableArray array];
    for (NSDictionary *device in _all) {
        if ([self matches:@[device[@"who"] ?: @"", device[@"dev"] ?: @"",
                            device[@"what"] ?: @""]]) {
            [kept addObject:device];
        }
    }
    _rows = kept;
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

            self->_all = rows;
            [self queryChanged];
            [self loaded];
        }];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }
- (NSString *)emptyMessage { return @"لا أجهزة معروفة بعد."; }

- (void)tapped:(NSInteger)row {
    NSDictionary *device = _rows[(NSUInteger)row];
    [self copyText:device[@"dev"]];
}

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


#pragma mark - Products

/// Which tweak is actually being used, from what the devices themselves report.
///
/// **The data was already arriving and nobody was counting it.** Every tweak writes its product
/// and version into the licence on check-in, so "which of these is worth my week" has had an
/// answer sitting in the records for months. Two numbers per tool, because they are two
/// questions: how many devices have *ever* run it, and how many ran it in the last week — only
/// the second says whether it is alive.
@implementation SCIProductsPage {
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    if ((self = [super init])) self.title = @"الأدوات";
    return self;
}

- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        NSMutableDictionary<NSString *, NSMutableDictionary *> *tally = [NSMutableDictionary
            dictionary];
        double week = [NSDate date].timeIntervalSince1970 - 7 * 86400;

        for (NSDictionary *licence in state[@"licences"] ?: @[]) {
            NSDictionary *installs = licence[@"installs"];
            if (![installs isKindOfClass:[NSDictionary class]]) continue;

            for (NSString *product in installs) {
                NSDictionary *seen = installs[product];
                if (![seen isKindOfClass:[NSDictionary class]]) continue;

                NSMutableDictionary *row = tally[product];
                if (!row) {
                    row = [@{@"product": product, @"all": @0, @"week": @0,
                             @"version": seen[@"version"] ?: @"—", @"at": @0} mutableCopy];
                    tally[product] = row;
                }

                row[@"all"] = @([row[@"all"] integerValue] + 1);
                if ([seen[@"at"] doubleValue] > week) {
                    row[@"week"] = @([row[@"week"] integerValue] + 1);
                }

                // The newest version seen wins the row's label: an old one on a forgotten phone
                // says nothing about what people are running.
                if ([seen[@"at"] doubleValue] > [row[@"at"] doubleValue]) {
                    row[@"at"] = seen[@"at"] ?: @0;
                    row[@"version"] = seen[@"version"] ?: @"—";
                }
            }
        }

        self->_rows = [tally.allValues sortedArrayUsingComparator:^NSComparisonResult(
                NSDictionary *a, NSDictionary *b) {
            return [b[@"week"] compare:a[@"week"]];
        }];
        [self loaded];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }

- (NSString *)emptyMessage {
    return @"لا شيء بعد.\nتُسجَّل الأداة ونسختها عند أوّل مزامنة من الجهاز.";
}

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *tool = _rows[(NSUInteger)row];

    cell.textLabel.text = SCIRun(tool[@"product"]);
    cell.detailTextLabel.text = [NSString stringWithFormat:
        @"%@ نشِطاً هذا الأسبوع  ·  %@ إجمالاً\nآخر نسخة %@ · %@",
        tool[@"week"], tool[@"all"], SCIRun(tool[@"version"]),
        SCIRun([SCIPage dateFrom:tool[@"at"]])];

    NSInteger week = [tool[@"week"] integerValue];
    cell.textLabel.textColor = week ? [UIColor labelColor] : [UIColor secondaryLabelColor];
}

@end


#pragma mark - Messages

/// The four sentences this app sends, and the placeholders they are filled from.
@implementation SCIMessagesPage

- (instancetype)init {
    if ((self = [super init])) self.title = @"رسائل واتساب";
    return self;
}

- (void)fetch { [self loaded]; }
- (NSInteger)rowCount { return SCIMessageCount; }

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    SCIMessageKind kind = (SCIMessageKind)row;

    cell.textLabel.text = [SCIMessages nameOf:kind];
    cell.detailTextLabel.text = [SCIMessages textFor:kind];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [SCIMessages isEdited:kind] ? [UIColor labelColor]
                                                                 : [UIColor secondaryLabelColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tapped:(NSInteger)row {
    SCIMessageKind kind = (SCIMessageKind)row;
    __weak typeof(self) weakSelf = self;

    [self askTitled:[SCIMessages nameOf:kind]
            message:@"{name} {device} {scope} {until} تُملأ من الترخيص. اتركها فارغة للعودة "
                     "إلى النصّ الأصلي."
              value:[SCIMessages textFor:kind] keyboard:UIKeyboardTypeDefault
               then:^(NSString *text) {
        [SCIMessages setText:text for:kind];
        [weakSelf reload];
    }];
}

@end


#pragma mark - Trials

/// Who took a free week, and the one thing that can be done about it.
///
/// **The record outlives the licence it created**, which is what makes the trial once per device
/// rather than once per week — so it has a screen of its own rather than being folded into the
/// devices list, where "why can this phone not take a trial" would have no answer.
@implementation SCITrialsPage {
    NSArray<NSDictionary *> *_all;
    NSArray<NSDictionary *> *_rows;
}

- (instancetype)init {
    if ((self = [super init])) self.title = @"الأسابيع المجانية";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self searchableWith:@"رمز جهاز"];
}

- (void)queryChanged {
    NSMutableArray *kept = [NSMutableArray array];
    for (NSDictionary *trial in _all) {
        if ([self matches:@[trial[@"key"] ?: @""]]) [kept addObject:trial];
    }
    _rows = kept;
}

- (void)fetch {
    [SCIAPI state:^(NSDictionary *state, NSString *error) {
        if (error) { [self failed:error]; return; }

        id rows = state[@"trials"];
        NSArray *all = [rows isKindOfClass:[NSArray class]] ? rows : @[];

        self->_all = [all sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,
                                                                        NSDictionary *b) {
            return [b[@"at"] ?: @0 compare:a[@"at"] ?: @0];   // newest first
        }];
        [self queryChanged];
        [self loaded];
    }];
}

- (NSInteger)rowCount { return (NSInteger)_rows.count; }

- (NSString *)emptyMessage {
    return @"لا أحد أخذ التجربة بعد.\nالسجلّ يبقى بعد انتهاء الأسبوع، وهو ما يجعلها مرّةً "
            "واحدة لكلّ جهاز.";
}

- (void)configure:(UITableViewCell *)cell at:(NSInteger)row {
    NSDictionary *trial = _rows[(NSUInteger)row];
    double until = [trial[@"until"] doubleValue];
    BOOL running = until > [NSDate date].timeIntervalSince1970;

    cell.textLabel.text = SCIRun(trial[@"key"] ?: @"?");
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    // ∞ belongs to a term with no end. A trial always ends, so a missing date here is a missing
    // date and says so — the same sentinel confusion the devices list had.
    NSString *ends = until > 0 ? [SCIPage dateFrom:trial[@"until"]] : @"—";

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  أُخذ %@  ·  ينتهي %@",
        running ? @"جارٍ" : @"انتهى", SCIRun([SCIPage dateFrom:trial[@"at"]]), SCIRun(ends)];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tapped:(NSInteger)row {
    NSDictionary *trial = _rows[(NSUInteger)row];
    NSString *device = trial[@"key"] ?: @"";
    __weak typeof(self) weakSelf = self;

    [self sheetTitled:device message:nil choices:@[
        [SCIChoice titled:@"انسخ رمز الجهاز" does:^{ [weakSelf copyText:device]; }],

        // The server deletes the licence alongside the trial record, and that is said here rather
        // than discovered: it is the difference between "grant another week" and "take away what
        // they are using right now".
        [SCIChoice dangerous:@"امنحه أسبوعاً آخر" does:^{
            [weakSelf sheetTitled:@"أسبوع مجاني آخر"
                          message:@"يُحذف سجلّ التجربة وأيّ ترخيصٍ قائم لهذا الجهاز، فيستطيع "
                                   "أخذ أسبوعه من جديد."
                          choices:@[[SCIChoice dangerous:@"امنح" does:^{
                [SCIAPI call:@"/admin/delete" body:@{@"dev": device, @"trial": @YES}
                        then:^(NSDictionary *answer, NSString *error) {
                    if (error) { [weakSelf failed:error]; return; }
                    [weakSelf say:@"يستطيع أخذ أسبوعٍ جديد"];
                    [weakSelf reload];
                }];
            }]]];
        }],
    ]];
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

    // Scope first, then term, then how many. **A minting route that cannot mint every scope is a
    // scope nobody can sell**, which is the mistake the web panel made in exactly this card.
    [self pickScope:^(NSString *tier) {
    [weakSelf sheetTitled:@"مدّة الكود" message:@"تبدأ عند استعماله، لا عند إصداره" choices:@[
        [SCIChoice titled:@"شهر" does:^{ [weakSelf mintTier:tier days:30]; }],
        [SCIChoice titled:@"ستّة أشهر" does:^{ [weakSelf mintTier:tier days:180]; }],
        [SCIChoice titled:@"سنة" does:^{ [weakSelf mintTier:tier days:365]; }],
        [SCIChoice titled:@"مدى الحياة" does:^{ [weakSelf mintTier:tier days:0]; }],
    ]];
    }];
}

/// One picker for every place that sets a scope. (The licences page has its own copy of this
/// method for the same reason: two screens, one list, and the list itself is `SCIScopes()`.)
- (void)pickScope:(void (^)(NSString *tier))then {
    NSMutableArray<SCIChoice *> *choices = [NSMutableArray array];
    for (NSArray<NSString *> *scope in SCIScopes()) {
        [choices addObject:[SCIChoice titled:scope[1] does:^{ then(scope[0]); }]];
    }
    [self sheetTitled:@"ما الذي يغطّيه الكود؟" message:nil choices:choices];
}

- (void)mintTier:(NSString *)tier days:(NSInteger)days {
    __weak typeof(self) weakSelf = self;
    [self askTitled:@"كم كوداً؟" message:@"تُعرَض مرّةً واحدة، فانسخها فوراً"
              value:@"5" keyboard:UIKeyboardTypeNumberPad then:^(NSString *count) {
        [SCIAPI call:@"/admin/codes"
                body:@{@"count": @(count.integerValue ?: 1), @"days": @(days), @"window": @90,
                       @"tier": tier}
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
