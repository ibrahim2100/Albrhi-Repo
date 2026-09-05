#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "SCIKeychain.h"

///
/// The licence panel, on the phone.
///
/// **The screen is the published panel, loaded over https, and that is a decision rather than a
/// shortcut.** Six tables, a dialog, a search that folds Arabic digits, three signers that have to
/// agree byte for byte — all of it exists, is used every day, and was debugged this week. A second
/// implementation of the same thing in UIKit would be two of everything to keep in step, which is
/// the failure this project has written down about maps, about lists, and about a screen and the
/// report that mirrors it.
///
/// What the app adds is what a page cannot have:
///
///   * the admin token in the **Keychain** rather than in a browser's storage, injected into the
///     page after it loads so it is never typed on a phone keyboard in public;
///   * **Face ID** in front of it, because that token can revoke every licence sold;
///   * and pull to refresh, a real back gesture, and an icon on a home screen.
///
/// `file://` was the obvious way to bundle the page and is the wrong one: `crypto.subtle` exists
/// only in a secure context, so the signing path would be gone — silently, which is the word that
/// matters. https keeps the page exactly what it is on a desktop.
///
static NSString *const kPanelURL = @"https://ibrahim2100.github.io/albrhi-repo/licence-panel/";
static NSString *const kTokenKey = @"admin-token";
static NSString *const kBaseKey  = @"server-base";

@interface SCIPanelViewController : UIViewController <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *web;
@property (nonatomic, strong) UIView *shield;
@property (nonatomic, assign) BOOL unlocked;
@end

@implementation SCIPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];

    self.web = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.web.navigationDelegate = self;
    self.web.translatesAutoresizingMaskIntoConstraints = NO;
    self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    [self.view addSubview:self.web];

    // **The shield goes up before anything loads, not after.** A panel that appears for a moment
    // and is then covered has already shown a customer list to whoever was looking.
    self.shield = [[UIView alloc] init];
    self.shield.translatesAutoresizingMaskIntoConstraints = NO;
    self.shield.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.shield];

    UILabel *locked = [[UILabel alloc] init];
    locked.translatesAutoresizingMaskIntoConstraints = NO;
    locked.text = @"تراخيص البرهي";
    locked.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    locked.textAlignment = NSTextAlignmentCenter;
    [self.shield addSubview:locked];

    UIButton *unlock = [UIButton buttonWithType:UIButtonTypeSystem];
    unlock.translatesAutoresizingMaskIntoConstraints = NO;
    [unlock setTitle:@"افتح" forState:UIControlStateNormal];
    unlock.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [unlock addTarget:self action:@selector(unlock) forControlEvents:UIControlEventTouchUpInside];
    [self.shield addSubview:unlock];

    [NSLayoutConstraint activateConstraints:@[
        [self.web.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.web.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.web.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.web.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.shield.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.shield.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.shield.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.shield.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [locked.centerXAnchor constraintEqualToAnchor:self.shield.centerXAnchor],
        [locked.centerYAnchor constraintEqualToAnchor:self.shield.centerYAnchor constant:-20],
        [unlock.centerXAnchor constraintEqualToAnchor:self.shield.centerXAnchor],
        [unlock.topAnchor constraintEqualToAnchor:locked.bottomAnchor constant:16],
    ]];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pulled:) forControlEvents:UIControlEventValueChanged];
    self.web.scrollView.refreshControl = refresh;

    [self.web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:kPanelURL]]];

    // Locked again the moment the app leaves the screen. The alternative -- unlocking once per
    // launch -- means the phone in somebody else's hand is unlocked for as long as the app stays
    // in memory, which is days.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lock)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.unlocked) [self unlock];
}

- (void)lock {
    self.unlocked = NO;
    self.shield.hidden = NO;
}

- (void)unlock {
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"استعمل رمز الجهاز";

    NSError *error = nil;
    // Device passcode counts. Requiring biometry alone means a phone whose owner's face is not
    // recognised in the dark cannot reach its own licences.
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        // No passcode set at all: nothing to check against, so the shield would be a lock with no
        // key. It comes down, and that is the honest behaviour rather than a screen that can
        // never be opened.
        self.unlocked = YES;
        self.shield.hidden = YES;
        return;
    }

    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:@"لفتح لوحة التراخيص"
                      reply:^(BOOL success, __unused NSError *failure) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) return;
            self.unlocked = YES;
            self.shield.hidden = YES;
            [self fillInToken];
        });
    }];
}

- (void)pulled:(UIRefreshControl *)refresh {
    [self.web reload];
    [refresh endRefreshing];
}

///
/// Puts the stored token and server address into the page, and takes back whatever the page ends
/// up holding.
///
/// **Injected rather than typed.** A sixty-character admin token typed on a phone keyboard, in
/// public, is the one part of this that a screen lock does not help with — and it would be typed
/// on every launch, because a web view's storage is not somewhere to leave it either.
///
/// The read-back is the other half: the panel is the thing that knows whether a token works, so
/// whatever it is holding after a successful connection is what gets kept.
///
- (void)fillInToken {
    NSString *token = [SCIKeychain stringForKey:kTokenKey] ?: @"";
    NSString *base = [SCIKeychain stringForKey:kBaseKey] ?: @"";

    NSString *script = [NSString stringWithFormat:
        @"(function(){"
        @"  var t = document.getElementById('token');"
        @"  var b = document.getElementById('base');"
        @"  if (t && %@) { t.value = %@; }"
        @"  if (b && %@) { b.value = %@; }"
        @"  var save = document.getElementById('save');"
        @"  if (save && %@) { save.click(); }"
        @"  return (t ? t.value : '') + '\\n' + (b ? b.value : '');"
        @"})()",
        token.length ? @"true" : @"false", [self quoted:token],
        base.length ? @"true" : @"false", [self quoted:base],
        (token.length && base.length) ? @"true" : @"false"];

    [self.web evaluateJavaScript:script completionHandler:^(id result, __unused NSError *error) {
        if (![result isKindOfClass:[NSString class]]) return;

        NSArray<NSString *> *parts = [(NSString *)result componentsSeparatedByString:@"\n"];
        if (parts.count != 2) return;

        // Kept only when the page has something to keep. Writing an empty token over a good one
        // because a page had not finished loading is the kind of quiet loss this app exists to
        // prevent.
        if (parts[0].length) [SCIKeychain setString:parts[0] forKey:kTokenKey];
        if (parts[1].length) [SCIKeychain setString:parts[1] forKey:kBaseKey];
    }];
}

- (NSString *)quoted:(NSString *)text {
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[text ?: @""] options:0 error:NULL];
    NSString *array = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    // ["value"] -> "value". Escaping by hand is how a quote in a token becomes a syntax error in
    // an injected script, and JSON already knows the rules.
    return [array substringWithRange:NSMakeRange(1, array.length - 2)];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(__unused WKNavigation *)navigation {
    if (self.unlocked) [self fillInToken];
}

- (void)webView:(WKWebView *)webView
        didFailProvisionalNavigation:(__unused WKNavigation *)navigation
                           withError:(NSError *)error {
    // Said on the screen rather than left as a white page. The most likely cause is no network,
    // and a panel that shows nothing and explains nothing is indistinguishable from one that is
    // broken.
    NSString *html = [NSString stringWithFormat:
        @"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<body style='font:-apple-system-body;padding:2rem;text-align:center;color:#888'>"
        @"<p>تعذّر تحميل اللوحة.</p><p style='font-size:.8em'>%@</p>"
        @"<p style='font-size:.8em'>اسحب للأسفل لإعادة المحاولة.</p></body>",
        error.localizedDescription];
    [webView loadHTMLString:html baseURL:nil];
}

@end
