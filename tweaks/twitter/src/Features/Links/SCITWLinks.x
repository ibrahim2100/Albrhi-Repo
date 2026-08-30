#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import <objc/runtime.h>
#import "SCITWLinks.h"
#import "Prefs.h"
#import "SCILog.h"

@interface TFSTwitterEntityURL : NSObject
@property (nonatomic, copy, readonly) NSString *expandedURL;
@end

static BOOL sciEntityURLPresent = NO;
static NSUInteger sciLinksExpanded = 0, sciLinksCleaned = 0;
static NSUInteger sciOpenedInSafari = 0, sciSafariNoURL = 0;

/// Kept so a rewrite of the pasteboard cannot start a loop: writing a cleaned URL fires the
/// change notification again, and without remembering what we just wrote the observer would
/// answer its own edit for ever.
static NSString *sciLastWritten = nil;
static id sciPasteboardObserver = nil;


%group Links

%hook TFSTwitterEntityURL

/// `t.co` is a redirector; `expandedURL` is where the link actually goes. Answering with
/// the second is not hiding anything from X -- the model carries both, and this only
/// changes which one the interface is handed to draw.
- (NSString *)url {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefExpandLinks]) return %orig;

    NSString *expanded = self.expandedURL;
    if (!expanded.length) return %orig;

    sciLinksExpanded++;
    return expanded;
}

%end

%end


/// The two parameters X appends to a shared link, per host.
///
/// A fixed pair rather than "anything short": a link's own query is often what makes it
/// work, and dropping an unknown parameter to be safe is how a shared link stops resolving.
static NSDictionary<NSString *, NSArray<NSString *> *> *SCITrackingParameters(void) {
    static NSDictionary *parameters = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        parameters = @{
            @"x.com": @[@"s", @"t"],
            @"twitter.com": @[@"s", @"t"],
            @"mobile.x.com": @[@"s", @"t"],
            @"mobile.twitter.com": @[@"s", @"t"],
        };
    });
    return parameters;
}

static void SCICleanPasteboard(void) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefStripTracking]) return;

    UIPasteboard *board = [UIPasteboard generalPasteboard];

    // Asked before reading. `-hasURLs` does not bring the contents into this process, and
    // reading a pasteboard that holds no link would show the paste notification for nothing.
    if (!board.hasURLs) return;

    NSURL *url = board.URL;
    if (!url.host.length || !url.query.length) return;
    if ([url.absoluteString isEqualToString:sciLastWritten]) return;

    NSArray<NSString *> *unwanted = SCITrackingParameters()[url.host.lowercaseString];
    if (!unwanted.count) return;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *kept = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![unwanted containsObject:item.name]) [kept addObject:item];
    }

    if (kept.count == components.queryItems.count) return;

    components.queryItems = kept.count ? kept : nil;
    NSURL *cleaned = components.URL;
    if (!cleaned) return;

    sciLastWritten = cleaned.absoluteString;
    board.URL = cleaned;
    sciLinksCleaned++;
    SCILogV(@"links: stripped tracking parameters from a copied link");
}

/// The URL a Safari controller was built with, kept on the controller itself.
///
/// **Read from the initialiser rather than from the object afterwards.** 0.17.0 asked for
/// `initialURL` with KVC and got nil -- `SFSafariViewController` does not expose the URL
/// under that name -- so the hook fell through to X's own browser every single time, and
/// silently, because a missing URL was treated as "leave it alone". The initialiser is the
/// one place the URL is certainly in hand, and both of Apple's are hooked because X may
/// call either.
static char kSCISafariURL;

%group LinksSafari

%hook SFSafariViewController

- (instancetype)initWithURL:(NSURL *)url {
    id controller = %orig;
    if (controller && url) {
        objc_setAssociatedObject(controller, &kSCISafariURL, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return controller;
}

- (instancetype)initWithURL:(NSURL *)url configuration:(id)configuration {
    id controller = %orig;
    if (controller && url) {
        objc_setAssociatedObject(controller, &kSCISafariURL, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return controller;
}

/// X's in-app browser, handed straight to Safari instead.
///
/// Dismissed and re-opened rather than prevented: the controller is presented by X's own
/// code, which expects one back, and refusing to let it appear would leave that code
/// holding a screen that never shows. Letting it appear and standing it down immediately
/// keeps X's side of the transaction intact.
- (void)viewWillAppear:(BOOL)animated {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefOpenInSafari]) return;

    NSURL *url = objc_getAssociatedObject(self, &kSCISafariURL);
    if (!url) {
        // Recorded rather than passed over in silence. This is exactly the state 0.17.0 was
        // in for every link, and nothing said so.
        sciSafariNoURL++;
        return;
    }

    sciOpenedInSafari++;

    UIViewController *controller = (UIViewController *)self;
    [controller dismissViewControllerAnimated:NO completion:^{
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }];
}

%end

%end


NSString *SCITWLinksReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (!sciEntityURLPresent) {
        [parts addObject:@"TFSTwitterEntityURL not in this build"];
    } else {
        [parts addObject:[NSString stringWithFormat:@"%lu link(s) expanded",
                          (unsigned long)sciLinksExpanded]];
    }

    [parts addObject:sciPasteboardObserver
        ? [NSString stringWithFormat:@"%lu copied link(s) cleaned", (unsigned long)sciLinksCleaned]
        : @"pasteboard not watched"];
    [parts addObject:[NSString stringWithFormat:@"%lu opened in Safari, %lu with no url",
                      (unsigned long)sciOpenedInSafari, (unsigned long)sciSafariNoURL]];

    return [@"links: " stringByAppendingString:[parts componentsJoinedByString:@" · "]];
}

void SCITWInstallLinks(void) {
    sciEntityURLPresent = (NSClassFromString(@"TFSTwitterEntityURL") != nil);
    if (sciEntityURLPresent) {
        %init(Links);
    }

    // Watched always, and gated inside. The observer costs nothing while the preference is
    // off, and registering it later would mean a switch that needs the app restarted --
    // which is the kind of thing nobody reads the note about.
    sciPasteboardObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIPasteboardChangedNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
        SCICleanPasteboard();
    }];

    // SafariServices is Apple's, so the class is always there -- no presence check to make
    // and nothing to report as absent.
    %init(LinksSafari);

    SCILogV(@"links: entity url %d, pasteboard watched, safari hooked", sciEntityURLPresent);
}
