#import "SCIUpdateChecker.h"
#import "../../Utils.h"
#import "../../Tweak.h"
#import "../../SCIProject.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"

#import <dlfcn.h>

static NSString *const kEnabled  = @"update_check_enabled";
static NSString *const kLastSeen = @"update_last_checked";

// Once a day. Often enough that a release is noticed, rare enough that it is not
// a request on every launch, and well inside GitHub's unauthenticated limit.
static const NSTimeInterval kCheckInterval = 24 * 60 * 60;

// dladdr needs the address of something in this binary, and an Objective-C
// method has no address that can be taken. This empty C function exists purely to
// be that address.
static void SCIAddressAnchor(void) {}

@implementation SCIUpdateChecker

// MARK: - Which install is this

+ (BOOL)isJailbrokenInstall {
    static BOOL jailbroken = YES;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        // Ask the loader where this very code came from, rather than probing for
        // jailbreak files: a sideloaded build lives inside the .app, a package
        // installs outside it. The same dylib ships both ways, so this cannot be
        // decided at compile time.
        Dl_info info;
        if (dladdr((const void *)&SCIAddressAnchor, &info) && info.dli_fname) {
            NSString *path = @(info.dli_fname);
            if ([path containsString:@".app/"]) jailbroken = NO;
        }
    });

    return jailbroken;
}

// MARK: - Version comparison

/// Compares dotted numeric versions component by component, so 3.2.10 is correctly
/// newer than 3.2.9 — which a plain string compare gets backwards.
+ (BOOL)version:(NSString *)candidate isNewerThan:(NSString *)current {
    NSArray<NSString *> *a = [[candidate stringByReplacingOccurrencesOfString:@"v" withString:@""]
                              componentsSeparatedByString:@"."];
    NSArray<NSString *> *b = [[current stringByReplacingOccurrencesOfString:@"v" withString:@""]
                              componentsSeparatedByString:@"."];

    NSUInteger count = MAX(a.count, b.count);
    for (NSUInteger i = 0; i < count; i++) {
        // A missing component counts as zero: 3.2 and 3.2.0 are the same version.
        NSInteger left  = i < a.count ? [a[i] integerValue] : 0;
        NSInteger right = i < b.count ? [b[i] integerValue] : 0;

        if (left != right) return left > right;
    }
    return NO;
}

// MARK: - Fetch

+ (void)fetchLatest:(void (^)(NSString *version, NSString *notes, NSError *error))completion {
    NSString *api = [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/releases/latest",
                     SCIRepoOwner, SCIRepoName];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:api]];
    request.timeoutInterval = 15;
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithRequest:request
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            completion(nil, nil, error ?: [NSError errorWithDomain:@"albrhi" code:-1 userInfo:nil]);
            return;
        }

        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) {
            completion(nil, nil, [NSError errorWithDomain:@"albrhi" code:-2 userInfo:nil]);
            return;
        }

        NSString *tag = json[@"tag_name"];
        if (![tag isKindOfClass:[NSString class]] || !tag.length) {
            completion(nil, nil, [NSError errorWithDomain:@"albrhi" code:-3 userInfo:nil]);
            return;
        }

        NSString *notes = [json[@"body"] isKindOfClass:[NSString class]] ? json[@"body"] : @"";
        completion(tag, notes, nil);
    }];

    [task resume];
}

// MARK: - Presenting

/// Where to send someone who wants the update, which is not the same for everyone:
/// a jailbroken copy updates through the source, a sideloaded one needs the dylib.
+ (NSString *)destinationURL {
    if ([self isJailbrokenInstall]) return SCISourceURL;

    return [NSString stringWithFormat:@"https://github.com/%@/%@/releases/latest",
            SCIRepoOwner, SCIRepoName];
}

/// @c presenter may be nil — the launch check has none — and then whatever is
/// frontmost presents the alert.
+ (void)presentUpdate:(NSString *)version notes:(NSString *)notes from:(nullable UIViewController *)presenter {
    NSString *how = [self isJailbrokenInstall] ? SCILocalized(@"update_how_jailbreak")
                                               : SCILocalized(@"update_how_sideload");

    // Only the first few lines: release notes can run long, and an alert that has
    // to scroll is worse than one that says enough.
    NSString *summary = notes.length ? [notes substringToIndex:MIN((NSUInteger)300, notes.length)] : @"";
    NSString *message = summary.length ? [NSString stringWithFormat:@"%@\n\n%@", how, summary] : how;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:SCILocalized(@"update_available"), version]
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"update_open")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        NSURL *url = [NSURL URLWithString:[self destinationURL]];
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"update_later")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIViewController *host = presenter ?: topMostController();
    [host presentViewController:alert animated:YES completion:nil];
}

// MARK: - Entry points

+ (void)checkQuietly {
    if (![SCIUtils getBoolPref:kEnabled]) return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval last = [defaults doubleForKey:kLastSeen];

    if (last > 0 && [[NSDate date] timeIntervalSince1970] - last < kCheckInterval) return;

    [self fetchLatest:^(NSString *version, NSString *notes, NSError *error) {
        // Recorded even on failure, so a device that is offline does not retry on
        // every launch.
        [defaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kLastSeen];

        if (error || !version) return;
        if (![self version:version isNewerThan:SCIVersionString]) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentUpdate:version notes:notes from:nil];
        });
    }];
}

+ (void)checkFromSettings:(nullable UIViewController *)presenter {
    JGProgressHUD *hud = [SCIUtils showProgressHUDWithText:SCILocalized(@"update_checking")];

    [self fetchLatest:^(NSString *version, NSString *notes, NSError *error) {
        [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970]
                                                  forKey:kLastSeen];

        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissAnimated:YES];

            if (error || !version) {
                [SCIUtils showErrorHUDWithDescription:SCILocalized(@"update_failed")];
                return;
            }

            if ([self version:version isNewerThan:SCIVersionString]) {
                [self presentUpdate:version notes:notes from:presenter];
            } else {
                [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"update_current")];
            }
        });
    }];
}

@end
