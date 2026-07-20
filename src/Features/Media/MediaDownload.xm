#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import "../../Localization/SCILocalize.h"

static SCIDownloadDelegate *imageDownloadDelegate;
static SCIDownloadDelegate *audioDownloadDelegate;
static NSString *const SCIDownloadGestureName = @"com.albrhi.media-download.longpress";

static BOOL hasGestureNamed(UIView *view, NSString *name) {
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture.name isEqualToString:name]) return YES;
    }
    return NO;
}

static void addDownloadLongPressGesture(UIView *view, id target, SEL action) {
    if (hasGestureNamed(view, SCIDownloadGestureName)) return;

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:action];
    longPress.name = SCIDownloadGestureName;
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];
    longPress.cancelsTouchesInView = YES;

    for (UIGestureRecognizer *existing in view.gestureRecognizers) {
        [existing requireGestureRecognizerToFail:longPress];
    }

    [view addGestureRecognizer:longPress];
}

// Whether the user wants media saved straight to their photo library.
static BOOL saveDirectlyToPhotos () {
    // Default OFF to preserve the original share/quicklook behaviour unless opted in.
    return [SCIUtils getBoolPref:@"dw_save_to_camera"];
}

static void initDownloaders () {
    // Re-evaluate each time so a settings change takes effect without an app restart.
    BOOL toPhotos = saveDirectlyToPhotos();

    DownloadAction imageAction = toPhotos ? saveToPhotos : quickLook;

    imageDownloadDelegate = [[SCIDownloadDelegate alloc] initWithAction:imageAction showProgress:NO];
    // Audio always uses the share sheet (can't write raw audio to the Photos library).
    audioDownloadDelegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:YES];
}

// IGSundialViewerVideoCell.video is an IGMedia; the IGVideo hangs off it. Older
// builds hand back the IGVideo directly, so accept either shape.
static IGVideo *SCIVideoFromMediaLike(id mediaLike) {
    if (!mediaLike) return nil;

    id nested = nil;
    @try { nested = [mediaLike valueForKey:@"video"]; } @catch (__unused id e) {}

    return nested ?: mediaLike;
}

// Kept as a thin alias so existing call sites read unchanged; the quality
// picker, queue routing and delegate choice all live in SCIMediaDownloader now.
static void downloadVideoForIGVideo (IGVideo *video, UIView *anchorView) {
    [SCIMediaDownloader downloadVideo:video sourceLabel:nil anchor:anchorView];
}

// What a long-press on media does: "zoom" (default), "download", or "off".
// Download-by-press was crash-prone, so it is no longer the default.
static NSString *SCIPressActionMode(void) {
    NSString *mode = [SCIUtils getStringPref:@"media_press_action"];
    return mode.length ? mode : @"zoom";
}

// Peek-zoom: scale the pressed media while held, spring back on release.
static void SCIPerformZoom(UIView *view, UILongPressGestureRecognizer *sender) {
    if (!view) return;

    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
            [view.superview bringSubviewToFront:view];
            [UIView animateWithDuration:0.22 delay:0
                 usingSpringWithDamping:0.8 initialSpringVelocity:0.5
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{ view.transform = CGAffineTransformMakeScale(1.6, 1.6); }
                             completion:nil];
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            [UIView animateWithDuration:0.25 delay:0
                 usingSpringWithDamping:0.75 initialSpringVelocity:0.3
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{ view.transform = CGAffineTransformIdentity; }
                             completion:nil];
            break;
        }

        default:
            break;
    }
}

// Central gate for every media long-press handler. Returns YES only when the
// download branch should run; zoom/off are handled here as side effects.
static BOOL SCIShouldProceedWithDownloadPress(UIView *view, UILongPressGestureRecognizer *sender) {
    NSString *mode = SCIPressActionMode();

    if ([mode isEqualToString:@"off"]) return NO;
    if ([mode isEqualToString:@"zoom"]) { SCIPerformZoom(view, sender); return NO; }

    // "download"
    return sender.state == UIGestureRecognizerStateBegan;
}

/* * Feed * */

// Download feed images
%hook IGFeedPhotoView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_feed_posts"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    NSLog(@"[SCInsta] Adding feed photo download long press gesture recognizer");

    addDownloadLongPressGesture(self, self, @selector(handleLongPress:));
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    IGPhoto *photo = nil;

    if ([self.delegate isKindOfClass:%c(IGFeedItemPhotoCell)]) {
        IGFeedItemPhotoCellConfiguration *_configuration = MSHookIvar<IGFeedItemPhotoCellConfiguration *>(self.delegate, "_configuration");
        @try { photo = [_configuration valueForKey:@"photo"]; } @catch (__unused id e) {}
        if (!photo) {
            @try { photo = MSHookIvar<IGPhoto *>(_configuration, "_photo"); } @catch (__unused id e) {}
        }
    }
    else if ([self.delegate isKindOfClass:%c(IGFeedItemPagePhotoCell)]) {
        IGFeedItemPagePhotoCell *pagePhotoCell = self.delegate;

        photo = pagePhotoCell.pagePhotoPost.photo;
    }

    if (!photo) {
        @try { photo = [[self.delegate valueForKey:@"post"] valueForKey:@"photo"]; } @catch (__unused id e) {}
    }

    NSURL *photoUrl = [SCIUtils getPhotoUrl:photo];
    if (!photoUrl) {
        [SCIUtils showErrorHUDWithDescription:@"Could not extract photo url from post"];
        
        return;
    }

    // Download image & show in share menu
    initDownloaders();
    [imageDownloadDelegate downloadFileWithURL:photoUrl
                                 fileExtension:[[photoUrl lastPathComponent]pathExtension]
                                      hudLabel:nil];
}
%end

// Download feed videos
%hook IGModernFeedVideoCell.IGModernFeedVideoCell
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_feed_posts"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    NSLog(@"[SCInsta] Adding feed video download long press gesture recognizer");

    addDownloadLongPressGesture(self, self, @selector(handleLongPress:));
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    id feedItem = nil;
    @try { feedItem = [self mediaCellFeedItem]; } @catch (__unused id e) {}
    IGVideo *video = nil;
    @try { video = [feedItem valueForKey:@"video"]; } @catch (__unused id e) {}
    if (!video) {
        @try { video = [[self valueForKey:@"post"] valueForKey:@"video"]; } @catch (__unused id e) {}
    }

    if (video) {
        downloadVideoForIGVideo(video, self);
        return;
    }

    // Fallback to the old direct path.
    NSURL *videoUrl = [SCIUtils getVideoUrlForMedia:feedItem];
    if (!videoUrl) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }
    [SCIMediaDownloader downloadURL:videoUrl sourceLabel:nil isVideo:YES];
}
%end


/* * Reels * */

// Download reels (photos)
%hook IGSundialViewerPhotoView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_reels"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    NSLog(@"[SCInsta] Adding reels photo download long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    IGPhoto *_photo = MSHookIvar<IGPhoto *>(self, "_photo");

    NSURL *photoUrl = [SCIUtils getPhotoUrl:_photo];
    if (!photoUrl) {
        [SCIUtils showErrorHUDWithDescription:@"Could not extract photo url from reel"];

        return;
    }

    // Download image & show in share menu
    initDownloaders();
    [imageDownloadDelegate downloadFileWithURL:photoUrl
                                 fileExtension:[[photoUrl lastPathComponent]pathExtension]
                                      hudLabel:nil];
}
%end

// Download reels (videos)
%hook IGSundialViewerVideoCell
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_reels"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    NSLog(@"[SCInsta] Adding reels video download long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    BOOL audioEnabled = [SCIUtils getBoolPref:@"dw_reel_audio"];
    NSURL *videoUrl = [SCIUtils getVideoUrlForMedia:self.video];
    // Audio lives on IGMedia (not IGVideo); let the helper walk from the cell to find it.
    NSURL *audioUrl = audioEnabled ? [SCIUtils getAudioUrlForMedia:self] : nil;

    // If audio is available and enabled, let the user choose what to download.
    if (audioUrl && videoUrl) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dw_choice_video")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [SCIMediaDownloader downloadVideo:SCIVideoFromMediaLike(self.video) sourceLabel:nil anchor:self];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dw_choice_audio")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            initDownloaders();
            NSString *ext = [[audioUrl lastPathComponent] pathExtension];
            [audioDownloadDelegate downloadFileWithURL:audioUrl
                                         fileExtension:([ext length] ? ext : @"m4a")
                                              hudLabel:nil];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel") style:UIAlertActionStyleCancel handler:nil]];

        // iPad anchor
        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;

        UIViewController *presenter = topMostController();
        [presenter presentViewController:sheet animated:YES completion:nil];
        return;
    }

    if (!videoUrl) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    [SCIMediaDownloader downloadVideo:SCIVideoFromMediaLike(self.video) sourceLabel:nil anchor:self];
}
%end


/* * Stories * */

// Download story (images)
%hook IGStoryPhotoView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_story"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    NSLog(@"[SCInsta] Adding story photo download long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    NSURL *photoUrl = [SCIUtils getPhotoUrlForMedia:[self item]];
    if (!photoUrl) {
        [SCIUtils showErrorHUDWithDescription:@"Could not extract photo url from story"];
        
        return;
    }

    // Download image & show in share menu
    initDownloaders();
    [imageDownloadDelegate downloadFileWithURL:photoUrl
                                 fileExtension:[[photoUrl lastPathComponent]pathExtension]
                                      hudLabel:nil];
}
%end

// Download story (videos)
%hook IGStoryModernVideoView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_story"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    //NSLog(@"[SCInsta] Adding story video download long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    // Route through downloadMedia so the quality picker applies here too — story
    // videos previously bypassed it by resolving a single URL directly.
    id item = self.item;
    if (item) {
        [SCIMediaDownloader downloadMedia:item sourceLabel:nil anchor:self];
        return;
    }

    NSURL *videoUrl = [SCIUtils getVideoUrlForMedia:self.item];
    if (!videoUrl) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    [SCIMediaDownloader downloadURL:videoUrl sourceLabel:nil isVideo:YES];
}
%end

// Download story (videos, legacy)
%hook IGStoryVideoView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"dw_story"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    //NSLog(@"[SCInsta] Adding story video download long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (!SCIShouldProceedWithDownloadPress(self, sender)) return;

    IGStoryFullscreenSectionController *captionDelegate = self.captionDelegate;
    if (captionDelegate) {
        // Story item is an IGMedia — route through downloadMedia for the quality picker.
        id item = captionDelegate.currentStoryItem;
        if (item) {
            [SCIMediaDownloader downloadMedia:item sourceLabel:nil anchor:self];
            return;
        }
    }
    else {
        // Direct messages video player
        id parentVC = [SCIUtils nearestViewControllerForView:self];
        if (!parentVC || ![parentVC isKindOfClass:%c(IGDirectVisualMessageViewerController)]) return;

        IGDirectVisualMessageViewerViewModeAwareDataSource *_dataSource = MSHookIvar<IGDirectVisualMessageViewerViewModeAwareDataSource *>(parentVC, "_dataSource");
        if (!_dataSource) return;

        IGDirectVisualMessage *_currentMessage = MSHookIvar<IGDirectVisualMessage *>(_dataSource, "_currentMessage");
        if (!_currentMessage) return;

        IGVideo *rawVideo = _currentMessage.rawVideo;
        if (!rawVideo) return;

        // rawVideo is an IGVideo — downloadVideo applies the picker when several renditions exist.
        [SCIMediaDownloader downloadVideo:rawVideo sourceLabel:nil anchor:self];
        return;
    }

    [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
}
%end


/* * Profile pictures * */

%hook IGProfilePictureImageView
- (void)didMoveToSuperview {
    %orig;

    // The long-press drives profile-picture saving, account-info copy and the
    // follow-status indicator — attach it if any of them is enabled.
    if ([SCIUtils getBoolPref:@"save_profile"]
        || [SCIUtils getBoolPref:@"copy_account_info"]
        || [SCIUtils getBoolPref:@"show_follow_status"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}
%new - (void)addLongPressGestureRecognizer {
    NSLog(@"[SCInsta] Adding profile picture long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSURL *imageUrl = nil;
    IGUser *user = nil;

    // Resolve the underlying user object once.
    @try { user = [self valueForKey:@"userGQL"]; } @catch (__unused id e) {}
    if (!user) { @try { user = [self valueForKey:@"user"]; } @catch (__unused id e) {} }

    // 1) Prefer the full-resolution HD URL from the user object.
    @try {
        if ([user respondsToSelector:@selector(HDMultipleProfilePicURLs)]) {
            id variants = [user HDMultipleProfilePicURLs];
            if ([variants isKindOfClass:[NSArray class]] && [variants count] > 0) {
                id last = [variants lastObject];
                if ([last isKindOfClass:[NSURL class]]) imageUrl = last;
                else if ([last isKindOfClass:[NSString class]]) imageUrl = [NSURL URLWithString:last];
                else if ([last respondsToSelector:@selector(url)]) imageUrl = [last performSelector:@selector(url)];
            }
        }
        if (!imageUrl && [user respondsToSelector:@selector(HDProfilePicURL)]) {
            imageUrl = [user HDProfilePicURL];
        }
        if (!imageUrl && [user respondsToSelector:@selector(profilePicURL)]) {
            imageUrl = [user profilePicURL];
        }
    } @catch (__unused id e) {}

    // 2) Fall back to whatever the on-screen image view is displaying.
    if (!imageUrl) {
        IGImageView *_imageView = MSHookIvar<IGImageView *>(self, "_imageView");
        if (_imageView) {
            IGImageSpecifier *imageSpecifier = _imageView.imageSpecifier;
            if (imageSpecifier) imageUrl = imageSpecifier.url;
        }
    }

    BOOL copyInfoEnabled = [SCIUtils getBoolPref:@"copy_account_info"];
    BOOL followStatusEnabled = [SCIUtils getBoolPref:@"show_follow_status"];

    // When account-info copy or the follow-status feature is enabled and we have a
    // user, present a choice sheet. The follow-back relationship shows as the sheet
    // message ("Follows you" / "Doesn't follow you").
    if ((copyInfoEnabled || followStatusEnabled) && user) {
        NSString *followMsg = followStatusEnabled ? [SCIUtils followStatusStringForUser:user] : nil;

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:followMsg preferredStyle:UIAlertControllerStyleActionSheet];

        if (imageUrl) {
            NSURL *finalUrl = imageUrl;
            [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"info_download_pfp")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                initDownloaders();
                [imageDownloadDelegate downloadFileWithURL:finalUrl
                                             fileExtension:[[finalUrl lastPathComponent] pathExtension]
                                                  hudLabel:SCILocalized(@"loading")];
            }]];
        }
        if (copyInfoEnabled) {
            [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"info_copy")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                [SCIUtils copyAccountInfoForUser:user];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel") style:UIAlertActionStyleCancel handler:nil]];

        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
        [topMostController() presentViewController:sheet animated:YES completion:nil];
        return;
    }

    if (!imageUrl) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_photo")];
        return;
    }

    // Download image & preview / save
    initDownloaders();
    [imageDownloadDelegate downloadFileWithURL:imageUrl
                                 fileExtension:[[imageUrl lastPathComponent] pathExtension]
                                      hudLabel:SCILocalized(@"loading")];
}
%end
