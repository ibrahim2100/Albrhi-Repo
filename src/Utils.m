#import "Utils.h"
#import <objc/runtime.h>

// Delegate that persists the chosen accent color as a hex string.
@interface SCIAccentPickerDelegate : NSObject <UIColorPickerViewControllerDelegate>
@end

@implementation SCIAccentPickerDelegate
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    NSString *hex = [SCIUtils hexStringFromColor:viewController.selectedColor];
    if (hex) [[NSUserDefaults standardUserDefaults] setObject:hex forKey:@"albrhi_accent_hex"];
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    NSString *hex = [SCIUtils hexStringFromColor:viewController.selectedColor];
    if (hex) [[NSUserDefaults standardUserDefaults] setObject:hex forKey:@"albrhi_accent_hex"];
    [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"accent_color_title")];
}
@end

@implementation SCIUtils

+ (BOOL)getBoolPref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return false;

    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}
+ (double)getDoublePref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return 0;

    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}
+ (NSString *)getStringPref:(NSString *)key {
    if (![key length] || [[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) return @"";

    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}

+ (_Bool)liquidGlassEnabledBool:(_Bool)fallback {
    BOOL setting = [SCIUtils getBoolPref:@"liquid_glass_surfaces"];
    return setting ? true : fallback;
}

+ (void)cleanCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSError *> *deletionErrors = [NSMutableArray array];

    // Temp folder
    // * disabled bc app crashed trying to delete certain files inside it
    // todo: remove the above disclaimer if this new code doesn't cause crashing
    NSArray *tempFolderContents = [fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    for (NSURL *fileURL in tempFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }

    // Analytics folder
    NSString *analyticsFolder = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Application Support/com.burbn.instagram/analytics"];
    NSArray *analyticsFolderContents = [fileManager contentsOfDirectoryAtURL:[[NSURL alloc] initFileURLWithPath:analyticsFolder] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    for (NSURL *fileURL in analyticsFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }
    
    // Caches folder
    NSString *cachesFolder = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Caches"];
    NSArray *cachesFolderContents = [fileManager contentsOfDirectoryAtURL:[[NSURL alloc] initFileURLWithPath:cachesFolder] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *fileURL in cachesFolderContents) {
        NSError *cacheItemDeletionError;
        [fileManager removeItemAtURL:fileURL error:&cacheItemDeletionError];

        if (cacheItemDeletionError) [deletionErrors addObject:cacheItemDeletionError];
    }

    // Log errors
    if (deletionErrors.count > 1) {

        for (NSError *error in deletionErrors) {
            NSLog(@"[SCInsta] File Deletion Error: %@", error);
        }

    }

}

// Displaying View Controllers
+ (void)showQuickLookVC:(NSArray<id> *)items {
    QLPreviewController *previewController = [[QLPreviewController alloc] init];
    QuickLookDelegate *quickLookDelegate = [[QuickLookDelegate alloc] initWithPreviewItemURLs:items];

    previewController.dataSource = quickLookDelegate;
    
    [topMostController() presentViewController:previewController animated:true completion:nil];
}
+ (void)showShareVC:(id)item {
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    if (is_iPad()) {
        acVC.popoverPresentationController.sourceView = topMostController().view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [topMostController() presentViewController:acVC animated:true completion:nil];
}
+ (void)showSettingsVC:(UIWindow *)window {
    UIViewController *rootController = [window rootViewController];
    SCISettingsViewController *settingsViewController = [SCISettingsViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    
    [rootController presentViewController:navigationController animated:YES completion:nil];
}

// Colours
+ (UIColor *)SCIColor_Primary {
    // Custom accent override (hex stored by the settings color picker)
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:@"albrhi_accent_hex"];
    UIColor *custom = [self colorFromHexString:hex];
    if (custom) return custom;

    // Albrhi default — burnt orange #E8590C
    return [UIColor colorWithRed:232/255.0 green:89/255.0 blue:12/255.0 alpha:1];
};

// Parse a #RRGGBB / RRGGBB hex string into a UIColor. Returns nil on invalid input.
+ (UIColor *)colorFromHexString:(NSString *)hex {
    if (![hex isKindOfClass:[NSString class]] || hex.length == 0) return nil;
    NSString *s = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length != 6) return nil;

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexInt:&rgb]) return nil;

    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

// Convert a UIColor to a #RRGGBB hex string.
+ (NSString *)hexStringFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return nil;
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)roundf(r * 255), (int)roundf(g * 255), (int)roundf(b * 255)];
}

// Errors
+ (NSError *)errorWithDescription:(NSString *)errorDesc {
    return [self errorWithDescription:errorDesc code:1];
}
+ (NSError *)errorWithDescription:(NSString *)errorDesc code:(NSInteger)errorCode {
    NSError *error = [ NSError errorWithDomain:@"com.socuul.scinsta" code:errorCode userInfo:@{ NSLocalizedDescriptionKey: errorDesc } ];
    return error;
}

+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc {
    return [self showErrorHUDWithDescription:errorDesc dismissAfterDelay:4.0];
}
+ (JGProgressHUD *)showErrorHUDWithDescription:(NSString *)errorDesc dismissAfterDelay:(CGFloat)dismissDelay {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = errorDesc;
    hud.indicatorView = [[JGProgressHUDErrorIndicatorView alloc] init];

    [hud showInView:topMostController().view];
    [hud dismissAfterDelay:4.0];

    return hud;
}
+ (JGProgressHUD *)showSuccessHUDWithDescription:(NSString *)desc {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = desc;
    hud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];

    [hud showInView:topMostController().view];
    [hud dismissAfterDelay:1.6];

    return hud;
}

// Present the system color picker to choose a custom accent color.
+ (void)showAccentColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.selectedColor = [self SCIColor_Primary];
        picker.supportsAlpha = NO;

        // Use a shared delegate object retained via associated storage.
        SCIAccentPickerDelegate *delegate = [[SCIAccentPickerDelegate alloc] init];
        objc_setAssociatedObject(picker, "albrhiAccentDelegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        picker.delegate = delegate;

        [topMostController() presentViewController:picker animated:YES completion:nil];
    } else {
        [self showErrorHUDWithDescription:@"iOS 14+ required"];
    }
}

+ (void)resetAccentColor {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"albrhi_accent_hex"];
    [self showSuccessHUDWithDescription:SCILocalized(@"accent_reset_title")];
}

// Compose and copy a user's public info (username, name, verified) to the clipboard.
+ (void)copyAccountInfoForUser:(id)user {
    if (!user) {
        [self showErrorHUDWithDescription:SCILocalized(@"info_unavailable")];
        return;
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    @try {
        if ([user respondsToSelector:@selector(username)]) {
            NSString *u = [user valueForKey:@"username"];
            if ([u isKindOfClass:[NSString class]] && u.length) [parts addObject:[NSString stringWithFormat:@"@%@", u]];
        }
    } @catch (__unused id e) {}

    @try {
        if ([user respondsToSelector:@selector(displayName)]) {
            NSString *n = [user performSelector:@selector(displayName)];
            if ([n isKindOfClass:[NSString class]] && n.length) [parts addObject:n];
        }
    } @catch (__unused id e) {}

    @try {
        if ([user respondsToSelector:@selector(computedIsVerified)] && [user computedIsVerified]) {
            [parts addObject:SCILocalized(@"info_verified")];
        }
    } @catch (__unused id e) {}

    if (parts.count == 0) {
        [self showErrorHUDWithDescription:SCILocalized(@"info_unavailable")];
        return;
    }

    [UIPasteboard generalPasteboard].string = [parts componentsJoinedByString:@"\n"];
    [self showSuccessHUDWithDescription:SCILocalized(@"info_copied")];
}

// Media
+ (NSURL *)getPhotoUrl:(IGPhoto *)photo {
    if (!photo) return nil;

    // Get highest quality photo link
    NSURL *photoUrl = [photo imageURLForWidth:100000.00];

    return photoUrl;
}
+ (NSURL *)getPhotoUrlForMedia:(IGMedia *)media {
    if (!media) return nil;

    IGPhoto *photo = media.photo;

    return [SCIUtils getPhotoUrl:photo];
}
// Extract the pixel area (width*height) from a version dictionary, if present.
// Read a numeric-ish property from either an IGAPIVideoVersion object (via
// selectors width/height/bandwidth) or an NSDictionary (via keys). Returns 0 if absent.
+ (long long)qualityValueFrom:(id)version key:(NSString *)key {
    if (!version) return 0;

    // Dictionary shape
    if ([version isKindOfClass:[NSDictionary class]]) {
        id v = version[key];
        // dictionaries may also carry a bandwidth under alternate keys
        if (!v && [key isEqualToString:@"bandwidth"]) {
            v = version[@"bitrate"] ?: version[@"estimated_bytes"];
        }
        return v ? [v longLongValue] : 0;
    }

    // Object shape (IGAPIVideoVersion): -width, -height, -bandwidth return NSNumber (id)
    @try {
        if ([version respondsToSelector:NSSelectorFromString(key)]) {
            id v = [version valueForKey:key];
            if ([v respondsToSelector:@selector(longLongValue)]) return [v longLongValue];
        }
    } @catch (__unused id e) {}
    return 0;
}

// Read the URL string from an IGAPIVideoVersion object or dictionary.
+ (NSString *)urlStringFromVersion:(id)version {
    if (!version) return nil;
    if ([version isKindOfClass:[NSDictionary class]]) {
        id u = version[@"url"] ?: version[@"urlString"];
        return [u isKindOfClass:[NSString class]] ? u : nil;
    }
    @try {
        for (NSString *sel in @[@"urlString", @"url"]) {
            if ([version respondsToSelector:NSSelectorFromString(sel)]) {
                id u = [version valueForKey:sel];
                if ([u isKindOfClass:[NSString class]]) return u;
                if ([u isKindOfClass:[NSURL class]]) return [(NSURL *)u absoluteString];
            }
        }
    } @catch (__unused id e) {}
    return nil;
}

// Pick the highest-quality entry from a collection of version objects/dicts.
+ (NSURL *)bestURLFromVersions:(id)versions {
    if (![versions respondsToSelector:@selector(count)] || [versions count] == 0) return nil;

    id best = nil;
    long long bestScore = -1;
    for (id version in versions) {
        NSString *urlString = [self urlStringFromVersion:version];
        if (![urlString length]) continue;

        long long w = [self qualityValueFrom:version key:@"width"];
        long long h = [self qualityValueFrom:version key:@"height"];
        long long area = w * h;
        long long bandwidth = [self qualityValueFrom:version key:@"bandwidth"];
        // Primary: pixel area. Tie-break: bandwidth. Fall back to bandwidth if no dimensions.
        long long score = (area > 0) ? (area * 1000000LL + bandwidth) : bandwidth;
        if (score > bestScore) { bestScore = score; best = version; }
    }
    if (!best) return nil;
    NSString *urlString = [self urlStringFromVersion:best];
    return [urlString length] ? [NSURL URLWithString:urlString] : nil;
}

+ (NSURL *)getVideoUrl:(IGVideo *)video {
    if (!video) return nil;

    BOOL preferMaxQuality = ([[NSUserDefaults standardUserDefaults] objectForKey:@"dw_max_quality"] == nil)
        ? YES // default ON
        : [[NSUserDefaults standardUserDefaults] boolForKey:@"dw_max_quality"];

    // --- Strategy 1: videoVersions → array of IGAPIVideoVersion (width/height/bandwidth) ---
    // This is the correct shape on current Instagram builds.
    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];
            if (preferMaxQuality) {
                NSURL *best = [self bestURLFromVersions:versions];
                if (best) return best;
            } else if ([versions respondsToSelector:@selector(firstObject)]) {
                // Lowest quality requested: versions are typically ordered high→low, so take last.
                id last = [versions respondsToSelector:@selector(lastObject)] ? [versions lastObject] : nil;
                NSString *u = [self urlStringFromVersion:last];
                if ([u length]) return [NSURL URLWithString:u];
            }
        }
    } @catch (__unused id e) {}

    // --- Strategy 2 (pre-v398): sortedVideoURLsBySize is ASCENDING → take last for highest ---
    if ([video respondsToSelector:@selector(sortedVideoURLsBySize)]) {
        NSArray<NSDictionary *> *sorted = [video sortedVideoURLsBySize];
        if ([sorted isKindOfClass:[NSArray class]] && sorted.count > 0) {
            NSDictionary *pick = preferMaxQuality ? sorted.lastObject : sorted.firstObject;
            NSString *urlString = pick[@"url"];
            if (urlString.length) return [NSURL URLWithString:urlString];
        }
    }

    // --- Strategy 3 (fallback): allVideoURLs is an UNORDERED set with no metadata ---
    if ([video respondsToSelector:@selector(allVideoURLs)]) {
        id urls = [video allVideoURLs];
        if ([urls isKindOfClass:[NSSet class]]) return [(NSSet *)urls anyObject];
        if ([urls isKindOfClass:[NSArray class]] && [(NSArray *)urls count] > 0) return [(NSArray *)urls lastObject];
    }

    return nil;
}
+ (NSURL *)getVideoUrlForMedia:(id)media {
    if (!media) return nil;

    IGVideo *video = nil;
    @try { video = [media valueForKey:@"video"]; } @catch (__unused id e) {}
    if (!video) return nil;

    return [SCIUtils getVideoUrl:video];
}

// Returns an array of @{ @"label": NSString, @"url": NSURL } for every available
// video quality, sorted highest-first. Used by the pre-download quality picker.
+ (NSArray<NSDictionary *> *)availableVideoQualitiesForVideo:(IGVideo *)video {
    if (!video) return @[];

    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    @try {
        if ([video respondsToSelector:@selector(videoVersions)]) {
            id versions = [video performSelector:@selector(videoVersions)];
            if ([versions respondsToSelector:@selector(count)]) {
                for (id version in versions) {
                    NSString *urlString = [self urlStringFromVersion:version];
                    if (![urlString length]) continue;
                    long long w = [self qualityValueFrom:version key:@"width"];
                    long long h = [self qualityValueFrom:version key:@"height"];
                    NSString *label = (w > 0 && h > 0)
                        ? [NSString stringWithFormat:@"%lld×%lld", w, h]
                        : SCILocalized(@"quality_unknown");
                    [out addObject:@{ @"label": label,
                                      @"url": [NSURL URLWithString:urlString],
                                      @"area": @(w * h) }];
                }
            }
        }
    } @catch (__unused id e) {}

    // Sort highest area first
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"area"] compare:a[@"area"]];
    }];
    return out;
}
// Accepts an IGMedia directly, or any object exposing a media/feedItem accessor.
+ (NSURL *)getAudioUrlForMedia:(id)mediaLike {
    if (!mediaLike) return nil;

    // Resolve to the object that actually carries the audio asset selectors.
    id media = mediaLike;
    if (![media respondsToSelector:@selector(sundialOriginalAudioAsset)]) {
        for (NSString *accessor in @[@"media", @"feedItem", @"currentMedia", @"item", @"mediaView", @"video"]) {
            @try {
                if ([media respondsToSelector:NSSelectorFromString(accessor)]) {
                    id candidate = [media valueForKey:accessor];
                    if ([candidate respondsToSelector:@selector(sundialOriginalAudioAsset)]) {
                        media = candidate;
                        break;
                    }
                }
            } @catch (__unused id e) {}
        }
    }

    id asset = nil;
    @try {
        if ([media respondsToSelector:@selector(sundialOriginalAudioAsset)]) {
            asset = [media performSelector:@selector(sundialOriginalAudioAsset)];
        }
        if (!asset && [media respondsToSelector:@selector(sundialMusicAsset)]) {
            asset = [media performSelector:@selector(sundialMusicAsset)];
        }
    } @catch (__unused id e) {}
    if (!asset) return nil;

    @try {
        if ([asset respondsToSelector:@selector(audioFileUrl)]) {
            id u = [asset performSelector:@selector(audioFileUrl)];
            if ([u isKindOfClass:[NSURL class]]) return u;
            if ([u isKindOfClass:[NSString class]] && [u length]) return [NSURL URLWithString:u];
        }
    } @catch (__unused id e) {}
    return nil;
}

// View Controllers
+ (UIViewController *)viewControllerForView:(UIView *)view {
    NSString *viewDelegate = @"viewDelegate";
    if ([view respondsToSelector:NSSelectorFromString(viewDelegate)]) {
        return [view valueForKey:viewDelegate];
    }

    return nil;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view {
    NSString *_viewControllerForAncestor = @"_viewControllerForAncestor";
    if ([view respondsToSelector:NSSelectorFromString(_viewControllerForAncestor)]) {
        return [view valueForKey:_viewControllerForAncestor];
    }

    return nil;
}

+ (UIViewController *)nearestViewControllerForView:(UIView *)view {
    return [self viewControllerForView:view] ?: [self viewControllerForAncestralView:view];
}

// Functions
+ (NSString *)IGVersionString {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
};
+ (BOOL)isNotch {
    return [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom > 0;
};

+ (BOOL)existingLongPressGestureRecognizerForView:(UIView *)view {
    NSArray *allRecognizers = view.gestureRecognizers;

    for (UIGestureRecognizer *recognizer in allRecognizers) {
        if ([[recognizer class] isSubclassOfClass:[UILongPressGestureRecognizer class]]) {
            return YES;
        }
    }

    return NO;
}

// Alerts
+ (BOOL)showConfirmation:(void(^)(void))okHandler title:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        okHandler();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"No!" style:UIAlertActionStyleCancel handler:nil]];

    [topMostController() presentViewController:alert animated:YES completion:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler title:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        okHandler();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"No!" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (cancelHandler != nil) {
            cancelHandler();
        }
    }]];

    [topMostController() presentViewController:alert animated:YES completion:nil];

    return nil;
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler {
    return [self showConfirmation:okHandler title:nil];
};
+ (BOOL)showConfirmation:(void(^)(void))okHandler cancelHandler:(void(^)(void))cancelHandler {
    return [self showConfirmation:okHandler cancelHandler:cancelHandler title:nil];
}
+ (void)showRestartConfirmation {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Restart required" message:@"You must restart the app to apply this change" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];

    [topMostController() presentViewController:alert animated:YES completion:nil];
};

// Toasts
+ (void)showToastForDuration:(double)duration title:(NSString *)title {
    [SCIUtils showToastForDuration:duration title:title subtitle:nil];
}
+ (void)showToastForDuration:(double)duration title:(NSString *)title subtitle:(NSString *)subtitle {
    // Root VC
    Class rootVCClass = NSClassFromString(@"IGRootViewController");

    UIViewController *topMostVC = topMostController();
    if (![topMostVC isKindOfClass:rootVCClass]) return;

    IGRootViewController *rootVC = (IGRootViewController *)topMostVC;

    // Presenter
    IGActionableConfirmationToastPresenter *toastPresenter = [rootVC toastPresenter];
    if (toastPresenter == nil) return;

    // View Model
    Class modelClass = NSClassFromString(@"IGActionableConfirmationToastViewModel");
    IGActionableConfirmationToastViewModel *model = [modelClass new];
    
    [model setValue:title forKey:@"text_annotatedTitleText"];
    [model setValue:subtitle forKey:@"text_annotatedSubtitleText"];

    // Show new toast, after clearing existing one
    [toastPresenter hideAlert];
    [toastPresenter showAlertWithViewModel:model isAnimated:true animationDuration:duration presentationPriority:0 tapActionBlock:nil presentedHandler:nil dismissedHandler:nil];
}

// Math
+ (NSUInteger)decimalPlacesInDouble:(double)value {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:15]; // Allow enough digits for double precision
    [formatter setMinimumFractionDigits:0];
    [formatter setDecimalSeparator:@"."]; // Force dot for internal logic, then respect locale for final display if needed

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    // Find decimal separator
    NSRange decimalRange = [stringValue rangeOfString:formatter.decimalSeparator];

    if (decimalRange.location == NSNotFound) {
        return 0;
    } else {
        return stringValue.length - (decimalRange.location + decimalRange.length);
    }
}

// Ivars
+ (id)getIvarForObj:(id)obj name:(const char *)name {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return nil;

    return object_getIvar(obj, ivar);
}
+ (void)setIvarForObj:(id)obj name:(const char *)name value:(id)value {
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return;
    
    object_setIvarWithStrongDefault(obj, ivar, value);
}


@end
