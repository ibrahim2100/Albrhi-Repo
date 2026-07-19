#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../Localization/SCILocalize.h"

static SCIDownloadDelegate *imageDownloadDelegate;
static SCIDownloadDelegate *videoDownloadDelegate;
static SCIDownloadDelegate *audioDownloadDelegate;

// Whether the user wants media saved straight to their photo library.
static BOOL saveDirectlyToPhotos () {
    // Default OFF to preserve the original share/quicklook behaviour unless opted in.
    return [SCIUtils getBoolPref:@"dw_save_to_camera"];
}

static void initDownloaders () {
    // Re-evaluate each time so a settings change takes effect without an app restart.
    BOOL toPhotos = saveDirectlyToPhotos();

    DownloadAction imageAction = toPhotos ? saveToPhotos : quickLook;
    DownloadAction videoAction = toPhotos ? saveToPhotos : share;

    imageDownloadDelegate = [[SCIDownloadDelegate alloc] initWithAction:imageAction showProgress:NO];
    videoDownloadDelegate = [[SCIDownloadDelegate alloc] initWithAction:videoAction showProgress:YES];
    // Audio always uses the share sheet (can't write raw audio to the Photos library).
    audioDownloadDelegate = [[SCIDownloadDelegate alloc] initWithAction:share showProgress:YES];
}

// Download a video, optionally letting the user pick a resolution first.
// `anchorView` is used to anchor the action sheet on iPad.
static void downloadVideoForIGVideo (IGVideo *video, UIView *anchorView) {
    if (!video) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }

    BOOL showPicker = [SCIUtils getBoolPref:@"show_quality_picker"];
    NSArray<NSDictionary *> *qualities = showPicker ? [SCIUtils availableVideoQualitiesForVideo:video] : nil;

    // Only bother with a picker when there's a real choice.
    if (showPicker && qualities.count > 1) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:SCILocalized(@"quality_pick_title")
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSDictionary *q in qualities) {
            NSURL *url = q[@"url"];
            [sheet addAction:[UIAlertAction actionWithTitle:q[@"label"]
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                initDownloaders();
                [videoDownloadDelegate downloadFileWithURL:url
                                             fileExtension:[[url lastPathComponent] pathExtension]
                                                  hudLabel:nil];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
        sheet.popoverPresentationController.sourceView = anchorView;
        sheet.popoverPresentationController.sourceRect = anchorView.bounds;
        [topMostController() presentViewController:sheet animated:YES completion:nil];
        return;
    }

    // Default path: best quality (respects the dw_max_quality preference internally).
    NSURL *videoUrl = [SCIUtils getVideoUrl:video];
    if (!videoUrl) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_video")];
        return;
    }
    initDownloaders();
    [videoDownloadDelegate downloadFileWithURL:videoUrl
                                 fileExtension:[[videoUrl lastPathComponent] pathExtension]
                                      hudLabel:nil];
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

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    // Get photo instance
    IGPhoto *photo;

    if ([self.delegate isKindOfClass:%c(IGFeedItemPhotoCell)]) {
        IGFeedItemPhotoCellConfiguration *_configuration = MSHookIvar<IGFeedItemPhotoCellConfiguration *>(self.delegate, "_configuration");
        if (!_configuration) return;

        photo = MSHookIvar<IGPhoto *>(_configuration, "_photo");
    }
    else if ([self.delegate isKindOfClass:%c(IGFeedItemPagePhotoCell)]) {
        IGFeedItemPagePhotoCell *pagePhotoCell = self.delegate;

        photo = pagePhotoCell.pagePhotoPost.photo;
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

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = [SCIUtils getDoublePref:@"dw_finger_duration"];
    longPress.numberOfTouchesRequired = [SCIUtils getDoublePref:@"dw_finger_count"];

    [self addGestureRecognizer:longPress];
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    IGFeedItem *feedItem = [self mediaCellFeedItem];
    IGVideo *video = nil;
    @try { video = [feedItem valueForKey:@"video"]; } @catch (__unused id e) {}

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
    initDownloaders();
    [videoDownloadDelegate downloadFileWithURL:videoUrl
                                 fileExtension:[[videoUrl lastPathComponent] pathExtension]
                                      hudLabel:nil];
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
    if (sender.state != UIGestureRecognizerStateBegan) return;

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
    if (sender.state != UIGestureRecognizerStateBegan) return;

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
            initDownloaders();
            [videoDownloadDelegate downloadFileWithURL:videoUrl
                                         fileExtension:[[videoUrl lastPathComponent] pathExtension]
                                              hudLabel:nil];
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

    // Download video & show in share menu
    initDownloaders();
    [videoDownloadDelegate downloadFileWithURL:videoUrl
                                 fileExtension:[[videoUrl lastPathComponent] pathExtension]
                                      hudLabel:nil];
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
    if (sender.state != UIGestureRecognizerStateBegan) return;

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
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSURL *videoUrl = [SCIUtils getVideoUrlForMedia:self.item];
    
    if (!videoUrl) {
        [SCIUtils showErrorHUDWithDescription:@"Could not extract video url from story"];

        return;
    }

    // Download video & show in share menu
    initDownloaders();
    [videoDownloadDelegate downloadFileWithURL:videoUrl
                                 fileExtension:[[videoUrl lastPathComponent] pathExtension]
                                      hudLabel:nil];
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
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSURL *videoUrl;

    IGStoryFullscreenSectionController *captionDelegate = self.captionDelegate;
    if (captionDelegate) {
        videoUrl = [SCIUtils getVideoUrlForMedia:captionDelegate.currentStoryItem];
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
        
        videoUrl = [SCIUtils getVideoUrl:rawVideo];
    }
    
    if (!videoUrl) {
        [SCIUtils showErrorHUDWithDescription:@"Could not extract video url from story"];

        return;
    }

    // Download video & show in share menu
    initDownloaders();
    [videoDownloadDelegate downloadFileWithURL:videoUrl
                                 fileExtension:[[videoUrl lastPathComponent] pathExtension]
                                      hudLabel:nil];
}
%end


/* * Profile pictures * */

%hook IGProfilePictureImageView
- (void)didMoveToSuperview {
    %orig;

    if ([SCIUtils getBoolPref:@"save_profile"]) {
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

    // When account-info copy is enabled and we have a user, present a choice.
    if (copyInfoEnabled && user) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

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
        [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"info_copy")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [SCIUtils copyAccountInfoForUser:user];
        }]];
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