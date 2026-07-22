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
            SCILogV(@"[SCInsta] File Deletion Error: %@", error);
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
    UIViewController *rootController = [window rootViewController] ?: topMostController();
    while (rootController.presentedViewController) {
        rootController = rootController.presentedViewController;
    }

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

+ (JGProgressHUD *)showProgressHUDWithText:(NSString *)text {
    JGProgressHUD *hud = [[JGProgressHUD alloc] init];
    hud.textLabel.text = text;
    [hud showInView:topMostController().view];
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

    // Append the follow-back relationship when known.
    NSString *followStatus = [self followStatusStringForUser:user];
    if (followStatus.length) [parts addObject:followStatus];

    [UIPasteboard generalPasteboard].string = [parts componentsJoinedByString:@"\n"];
    [self showSuccessHUDWithDescription:SCILocalized(@"info_copied")];
}

+ (NSString *)followStatusStringForUser:(id)user {
    if (!user) return nil;

    @try {
        // `followsCurrentUser` is the authoritative "do they follow me" flag.
        if ([user respondsToSelector:@selector(followsCurrentUser)]) {
            BOOL followsMe = [[user valueForKey:@"followsCurrentUser"] boolValue];
            return SCILocalized(followsMe ? @"p_follows_you" : @"p_not_follows_you");
        }
    } @catch (__unused id e) {}

    return nil;
}

+ (NSString *)currentUsername {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (![window respondsToSelector:@selector(userSession)]) continue;

            id session = [window valueForKey:@"userSession"];
            id user = session ? [session valueForKey:@"user"] : nil;
            id username = user ? [user valueForKey:@"username"] : nil;

            if ([username isKindOfClass:[NSString class]] && [username length]) return username;
        }
    } @catch (__unused id e) {}

    return nil;
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
        // Try every plausible accessor name — the exact one differs between
        // Instagram builds (urlString / url / progressiveDownloadURL / etc.).
        for (NSString *sel in @[@"urlString", @"url", @"progressiveDownloadURL", @"downloadURL", @"assetURL", @"videoURL"]) {
            if ([version respondsToSelector:NSSelectorFromString(sel)]) {
                id u = [version valueForKey:sel];
                if ([u isKindOfClass:[NSString class]] && [u length]) return u;
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

    // Always take the highest-quality rendition available (resolution, then bitrate).
    BOOL preferMaxQuality = YES;

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
+ (NSArray<NSString *> *)selectorsMatching:(NSString *)needle onObject:(id)object {
    if (!object || !needle.length) return @[];

    NSMutableArray<NSString *> *found = [NSMutableArray array];

    // Walk up to NSObject: the property may be declared on a superclass, and
    // stopping at the leaf would miss it.
    for (Class cls = [object class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        if (!methods) continue;

        for (unsigned int i = 0; i < count; i++) {
            SEL selector = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(selector);

            // Getters only: anything taking an argument cannot be probed blindly.
            if ([name containsString:@":"]) continue;

            if ([name rangeOfString:needle options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
            if ([found containsObject:name]) continue;

            [found addObject:name];
        }

        free(methods);
    }

    return [found copy];
}

+ (NSString *)dashManifestXMLForVideo:(id)video media:(id)media {
    // Names guessed from another tweak's symbol table found nothing on a real
    // device, so the candidate list is now built from what these objects
    // actually respond to. The manifest is reachable from either the video or
    // the media object depending on how the post was constructed, so both are
    // asked.
    for (id host in @[video ?: [NSNull null], media ?: [NSNull null]]) {
        if (host == [NSNull null]) continue;

        NSMutableArray<NSString *> *selectorNames =
            [[self selectorsMatching:@"dash" onObject:host] mutableCopy];

        for (NSString *name in [self selectorsMatching:@"manifest" onObject:host]) {
            if (![selectorNames containsObject:name]) [selectorNames addObject:name];
        }

        for (NSString *name in selectorNames) {
            SEL selector = NSSelectorFromString(name);
            if (![host respondsToSelector:selector]) continue;

            id value = nil;
            @try { value = [host performSelector:selector]; } @catch (__unused id e) { continue; }

            if ([value isKindOfClass:[NSString class]] && [value length]) return value;

            if ([value isKindOfClass:[NSData class]]) {
                NSString *text = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                if ([text length]) return text;
            }
        }

        // Some builds expose the field only through the API dictionary rather
        // than as a property, so KVC reaches it where respondsToSelector: does not.
        @try {
            id value = [host valueForKey:@"video_dash_manifest"];
            if ([value isKindOfClass:[NSString class]] && [value length]) return value;
        } @catch (__unused id e) {}
    }

    return nil;
}

// MARK: - DASH ladder

// Reads a numeric attribute (width="1080") from a single Representation block.
// The \b guards against width="…" matching inside bandWIDTH="…" — a bug that once
// reported the bitrate as the width.
+ (long long)dashInt:(NSString *)name inBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@=\"(\\d+)\"", name]
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return 0;
    return [[block substringWithRange:[m rangeAtIndex:1]] longLongValue];
}

// Reads a string attribute (codecs="avc1.64…") from a Representation block.
+ (NSString *)dashString:(NSString *)name inBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@=\"([^\"]+)\"", name]
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    return [block substringWithRange:[m rangeAtIndex:1]];
}

// Reads and XML-unescapes the <BaseURL> of a Representation block, absolute only.
+ (NSString *)dashBaseURLInBlock:(NSString *)block {
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"<BaseURL>(.*?)</BaseURL>"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil];
    NSTextCheckingResult *m = [regex firstMatchInString:block options:0 range:NSMakeRange(0, block.length)];
    if (!m || m.numberOfRanges < 2) return nil;

    NSString *url = [[block substringWithRange:[m rangeAtIndex:1]]
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    url = [url stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    url = [url stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    url = [url stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    url = [url stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];

    // Relative BaseURLs would need an MPD base we do not track.
    return [url hasPrefix:@"http"] ? url : nil;
}

// Which family a DASH codecs string belongs to, in terms of what iOS can save:
//   "h264" (avc1/avc3), "hevc" (hvc1/hev1), "av1" (av01), "vp9" (vp09/vp9), or nil.
// H.264/HEVC save straight to Photos; AV1/VP9 need transcoding first (phase two).
+ (NSString *)dashCodecFamily:(NSString *)codecs {
    NSString *c = [codecs lowercaseString];
    if (![c length]) return nil;
    if ([c hasPrefix:@"avc1"] || [c hasPrefix:@"avc3"]) return @"h264";
    if ([c hasPrefix:@"hvc1"] || [c hasPrefix:@"hev1"]) return @"hevc";
    if ([c hasPrefix:@"av01"]) return @"av1";
    if ([c hasPrefix:@"vp09"] || [c hasPrefix:@"vp9"]) return @"vp9";
    return nil;
}

+ (NSArray<NSDictionary *> *)dashRepresentationsForVideo:(id)video media:(id)media {
    return [self dashRepresentationsFromXML:[self dashManifestXMLForVideo:video media:media]];
}

+ (NSArray<NSDictionary *> *)dashRepresentationsFromXML:(NSString *)xml {
    if (![xml length] || [xml rangeOfString:@"<Representation"].location == NSNotFound) return @[];

    NSRegularExpression *repRegex =
        [NSRegularExpression regularExpressionWithPattern:@"<Representation\\b[^>]*>.*?</Representation>"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil];

    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];

    for (NSTextCheckingResult *match in [repRegex matchesInString:xml options:0 range:NSMakeRange(0, xml.length)]) {
        NSString *block = [xml substringWithRange:match.range];

        NSString *baseURL = [self dashBaseURLInBlock:block];
        if (![baseURL length]) continue;

        NSString *codecs = [self dashString:@"codecs" inBlock:block];
        long long w = [self dashInt:@"width" inBlock:block];
        long long h = [self dashInt:@"height" inBlock:block];
        long long bandwidth = [self dashInt:@"bandwidth" inBlock:block];

        // A Representation with no dimensions is the audio track; keep it tagged so
        // the transcoder can pair it with the decoded video stream.
        NSString *type = (w > 0 && h > 0) ? @"video" : @"audio";

        // frameRate is "num/den" (e.g. 15360/512 ≈ 30). The transcoder needs it to
        // stamp presentation times; default to 30 when absent or malformed.
        double fps = 30.0;
        NSString *fr = [self dashString:@"frameRate" inBlock:block];
        NSArray<NSString *> *parts = [fr componentsSeparatedByString:@"/"];
        if (parts.count == 2 && [parts[1] doubleValue] > 0) {
            fps = [parts[0] doubleValue] / [parts[1] doubleValue];
        } else if (parts.count == 1 && [fr doubleValue] > 0) {
            fps = [fr doubleValue];
        }

        [out addObject:@{
            @"type": type,
            @"url": baseURL,
            @"codecs": codecs ?: @"",
            @"family": [self dashCodecFamily:codecs] ?: @"",
            @"width": @(w),
            @"height": @(h),
            @"area": @(w * h),
            @"bandwidth": @(bandwidth),
            @"fps": @(fps)
        }];
    }

    return out;
}

// The best video URL that iOS can save as-is: the highest-resolution H.264/HEVC
// rendition across the DASH ladder AND -videoVersions.
//
// -videoVersions stays the floor and the safety net: if DASH exposes nothing
// saveable (an AV1-only reel, an exception, an unparsable manifest), this returns
// exactly what the proven path returned. AV1/VP9 renditions are ignored here —
// saving those is phase two's job, behind its own switch.
+ (NSURL *)getBestVideoUrl:(IGVideo *)video {
    NSURL *fallback = [self getVideoUrl:video];

    @try {
        long long fallbackArea = 0;
        NSURL *best = fallback;

        for (NSDictionary *rep in [self dashRepresentationsForVideo:video media:nil]) {
            if (![rep[@"type"] isEqualToString:@"video"]) continue;

            NSString *family = rep[@"family"];
            if (![family isEqualToString:@"h264"] && ![family isEqualToString:@"hevc"]) continue;

            long long area = [rep[@"area"] longLongValue];
            if (area <= fallbackArea) continue;

            NSURL *url = [NSURL URLWithString:rep[@"url"]];
            if (!url) {
                NSString *encoded = [rep[@"url"] stringByAddingPercentEncodingWithAllowedCharacters:
                                     [NSCharacterSet URLQueryAllowedCharacterSet]];
                url = [NSURL URLWithString:encoded];
            }
            if (!url) continue;

            best = url;
            fallbackArea = area;
        }

        return best;
    } @catch (__unused id e) {
        return fallback;
    }
}

+ (NSURL *)urlFromDashRep:(NSDictionary *)rep {
    if (!rep) return nil;
    NSURL *url = [NSURL URLWithString:rep[@"url"]];
    if (url) return url;
    NSString *encoded = [rep[@"url"] stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSURL URLWithString:encoded];
}

// Ranks one video representation above another: resolution first (a bigger frame
// is the headline win), then frame rate (so 1080p60 is taken over 1080p30 when
// both exist — the source's real smoothness, not a forced 30), then bitrate.
+ (BOOL)dashRep:(NSDictionary *)a beats:(NSDictionary *)b {
    long long areaA = [a[@"area"] longLongValue], areaB = [b[@"area"] longLongValue];
    if (areaA != areaB) return areaA > areaB;

    double fpsA = [a[@"fps"] doubleValue], fpsB = [b[@"fps"] doubleValue];
    if (fpsA != fpsB) return fpsA > fpsB;

    return [a[@"bandwidth"] longLongValue] > [b[@"bandwidth"] longLongValue];
}

+ (NSDictionary *)transcodePlanForVideo:(id)video media:(id)media {
    @try {
        NSArray<NSDictionary *> *reps = [self dashRepresentationsForVideo:video media:media];
        if (reps.count == 0) return nil;

        NSDictionary *bestAV1 = nil, *bestAudio = nil;
        long long bestSaveableHeight = 0;

        for (NSDictionary *rep in reps) {
            long long h = [rep[@"height"] longLongValue];
            NSString *family = rep[@"family"];

            if ([rep[@"type"] isEqualToString:@"audio"]) {
                if (!bestAudio || [rep[@"bandwidth"] longLongValue] > [bestAudio[@"bandwidth"] longLongValue]) {
                    bestAudio = rep;
                }
                continue;
            }

            // The tallest rendition iOS can already save without transcoding.
            if (([family isEqualToString:@"h264"] || [family isEqualToString:@"hevc"]) && h > bestSaveableHeight) {
                bestSaveableHeight = h;
            }

            if ([family isEqualToString:@"av1"]) {
                if (!bestAV1 || [self dashRep:rep beats:bestAV1]) {
                    bestAV1 = rep;
                }
            }
        }

        if (!bestAV1) return nil;

        // Only worth the transcode when AV1 clears both the DASH H.264 ladder and
        // the ~720p progressive rendition -videoVersions typically tops out at.
        long long av1Height = [bestAV1[@"height"] longLongValue];
        if (av1Height <= bestSaveableHeight || av1Height <= 720) return nil;

        NSURL *videoURL = [self urlFromDashRep:bestAV1];
        if (!videoURL) return nil;

        NSMutableDictionary *plan = [NSMutableDictionary dictionary];
        plan[@"videoURL"] = videoURL;
        plan[@"fps"] = bestAV1[@"fps"] ?: @30;
        plan[@"width"] = bestAV1[@"width"];
        plan[@"height"] = bestAV1[@"height"];

        // Clip duration (mediaPresentationDuration="PT10.517188S") lets the banner
        // show a real percentage: total frames ≈ duration × fps.
        NSString *xml = [self dashManifestXMLForVideo:video media:media];
        NSString *dur = [self dashString:@"mediaPresentationDuration" inBlock:xml ?: @""];
        if ([dur hasPrefix:@"PT"] && [dur hasSuffix:@"S"]) {
            double seconds = [[dur substringWithRange:NSMakeRange(2, dur.length - 3)] doubleValue];
            if (seconds > 0) plan[@"duration"] = @(seconds);
        }
        if (bestAudio) {
            NSURL *audioURL = [self urlFromDashRep:bestAudio];
            if (audioURL) plan[@"audioURL"] = audioURL;
        }
        return plan;
    } @catch (__unused id e) {
        return nil;
    }
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
