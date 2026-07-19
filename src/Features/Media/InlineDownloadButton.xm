#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Downloader/Download.h"
#import "../../Downloader/Queue/SCIDownloadQueue.h"
#import "../../Localization/SCILocalize.h"

///
/// Inline download button
///
/// Injects a native-looking download glyph into the post action row
/// (like · comment · send · … · save), so media can be saved with a single tap
/// instead of a long press.
///
/// The button is added to `IGUFIButtonBarView`, which owns the action row for
/// feed posts and carousels. It is laid out relative to the app's own save
/// button so it inherits Instagram's spacing, size and tint.
///

static const NSInteger SCIInlineDownloadButtonTag = 0x5CD10;

static SCIDownloadDelegate *inlineImageDelegate;
static SCIDownloadDelegate *inlineVideoDelegate;

static void SCIInitInlineDelegates(void) {
    // Re-evaluated per download so a settings change applies without a restart.
    BOOL toPhotos = [SCIUtils getBoolPref:@"dw_save_to_camera"];

    inlineImageDelegate = [[SCIDownloadDelegate alloc] initWithAction:(toPhotos ? saveToPhotos : quickLook)
                                                        showProgress:YES];
    inlineVideoDelegate = [[SCIDownloadDelegate alloc] initWithAction:(toPhotos ? saveToPhotos : share)
                                                        showProgress:YES];
}

// Pulls an IGMedia-like object off an arbitrary owner using the accessor names
// Instagram uses across its cell/delegate/view-model layers.
static id SCIMediaFromOwner(id owner) {
    if (!owner) return nil;

    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[@"media", @"post", @"feedItem", @"_media", @"_post"];
    });

    for (NSString *key in keys) {
        id candidate = nil;
        @try { candidate = [owner valueForKey:key]; } @catch (__unused id e) {}

        if (!candidate) continue;

        // Only accept objects that actually expose media payloads.
        BOOL hasVideo = NO, hasPhoto = NO;
        @try { hasVideo = ([candidate valueForKey:@"video"] != nil); } @catch (__unused id e) {}
        @try { hasPhoto = ([candidate valueForKey:@"photo"] != nil); } @catch (__unused id e) {}

        if (hasVideo || hasPhoto) return candidate;
    }

    return nil;
}

// Walks the delegate chain first, then the view hierarchy, looking for the media
// backing this action row.
static id SCIMediaForButtonBar(UIView *bar) {
    id delegate = nil;
    @try { delegate = [bar valueForKey:@"delegate"]; } @catch (__unused id e) {}

    id media = SCIMediaFromOwner(delegate);
    if (media) return media;

    // IGFeedItemUFICell forwards to its own delegate, which is created with the media.
    id nested = nil;
    @try { nested = [delegate valueForKey:@"delegate"]; } @catch (__unused id e) {}

    media = SCIMediaFromOwner(nested);
    if (media) return media;

    // Last resort: the enclosing cell.
    UIView *ancestor = bar.superview;
    while (ancestor) {
        media = SCIMediaFromOwner(ancestor);
        if (media) return media;

        ancestor = ancestor.superview;
    }

    return nil;
}

// "@username" for the post's author, used as the queue row subtitle. Best-effort:
// an unknown media shape just yields nil and the row shows no source.
static NSString *SCIUsernameForMedia(id media) {
    id user = nil;
    @try { user = [media valueForKey:@"user"]; } @catch (__unused id e) {}

    NSString *username = nil;
    @try { username = [user valueForKey:@"username"]; } @catch (__unused id e) {}

    return [username length] ? [NSString stringWithFormat:@"@%@", username] : nil;
}

static void SCIDownloadMedia(id media, UIView *anchorView) {
    if (!media) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    // Video takes precedence — a video post also carries a poster photo.
    NSURL *videoUrl = [SCIUtils getVideoUrlForMedia:media];
    NSURL *photoUrl = videoUrl ? nil : [SCIUtils getPhotoUrlForMedia:media];
    NSURL *url = videoUrl ?: photoUrl;

    if (!url) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"err_no_media")];
        return;
    }

    NSString *extension = [[url lastPathComponent] pathExtension];

    // Queue mode: hand off and let the transfer run in the background. The user
    // keeps scrolling; progress lives in the Download Center.
    if ([SCIUtils getBoolPref:@"dl_use_queue"]) {
        SCIDownloadQueue *queue = [SCIDownloadQueue shared];

        SCIDownloadJob *existing = [queue completedJobForURL:url];
        if (existing) {
            [SCIUtils showToastForDuration:1.6
                                     title:SCILocalized(@"dl_already_downloaded")
                                  subtitle:existing.displayName];
            return;
        }

        [queue enqueueURL:url
            fileExtension:extension
              displayName:nil
              sourceLabel:SCIUsernameForMedia(media)];

        [SCIUtils showToastForDuration:1.2 title:SCILocalized(@"dl_added_to_queue")];

        return;
    }

    // Direct mode: the original blocking HUD flow.
    SCIInitInlineDelegates();

    SCIDownloadDelegate *delegate = videoUrl ? inlineVideoDelegate : inlineImageDelegate;
    [delegate downloadFileWithURL:url fileExtension:extension hudLabel:nil];
}

%hook IGUFIButtonBarView

- (void)layoutSubviews {
    %orig;

    if (![SCIUtils getBoolPref:@"inline_download_button"]) {
        // Tear the button down if the user turned the feature off mid-session.
        UIView *existing = [self viewWithTag:SCIInlineDownloadButtonTag];
        if (existing) [existing removeFromSuperview];

        return;
    }

    [self sciLayoutInlineDownloadButton];
}

%new - (void)sciLayoutInlineDownloadButton {
    UIView *bar = (UIView *)self;

    UIButton *button = (UIButton *)[bar viewWithTag:SCIInlineDownloadButtonTag];

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = SCIInlineDownloadButtonTag;
        button.accessibilityLabel = SCILocalized(@"inline_download_title");

        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                            weight:UIImageSymbolWeightRegular];

        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:symbolConfig]
                forState:UIControlStateNormal];

        [button addTarget:self
                   action:@selector(sciInlineDownloadPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [bar addSubview:button];
    }

    // Mirror the save button so spacing, size and tint stay native.
    UIView *saveButton = nil;
    @try { saveButton = [self saveButton]; } @catch (__unused id e) {}

    CGFloat size = 24.0;
    CGFloat spacing = 16.0;
    CGRect frame;

    if (saveButton && !saveButton.hidden && !CGRectIsEmpty(saveButton.frame)) {
        CGRect saveFrame = saveButton.frame;
        size = CGRectGetHeight(saveFrame);

        frame = CGRectMake(CGRectGetMinX(saveFrame) - CGRectGetWidth(saveFrame) - spacing,
                           CGRectGetMinY(saveFrame),
                           CGRectGetWidth(saveFrame),
                           size);

        button.tintColor = saveButton.tintColor;
    }
    else {
        // No save button on this post — sit at the trailing edge instead.
        frame = CGRectMake(CGRectGetWidth(bar.bounds) - size - spacing,
                           (CGRectGetHeight(bar.bounds) - size) / 2.0,
                           size,
                           size);
    }

    // Never draw outside the bar; a negative origin means the layout isn't ready yet.
    button.hidden = (CGRectGetMinX(frame) < 0.0 || CGRectIsEmpty(bar.bounds));
    button.frame = frame;

    [bar bringSubviewToFront:button];
}

%new - (void)sciInlineDownloadPressed:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    SCIDownloadMedia(SCIMediaForButtonBar((UIView *)self), sender);
}

%end
