#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "SCIYTSponsorClient.h"
#import <objc/runtime.h>
#import <objc/message.h>

///
/// Skip the sponsored parts.
///
/// Three hooks, all on YTPlayerViewController, which is the one class that owns every
/// piece needed: it is told when a video activates, it is told when the time changes,
/// and it can seek. Checked against the binary rather than assumed -- the reference tweak
/// also hooks -singleVideo:currentVideoTimeDidChange: on this class, which it does not
/// implement, so that hook is added and then never called.
///
/// State is file-static rather than attached to the controller. One video plays at a
/// time, the controller is a singleton in practice, and associated objects on a class we
/// do not own are a lifetime problem to inherit for no gain here.
///

static NSString *sciCurrentVideoID = nil;
static NSArray<SCISponsorSegment *> *sciSegments = nil;

/// Segments already jumped over, by uuid.
///
/// Without this the skip repeats: seeking to the end of a segment fires another time
/// change, which is still near that segment, which seeks again. It also means a user who
/// scrubs back into a segment on purpose is left alone -- the tweak got its one say.
static NSMutableSet<NSString *> *sciSkipped = nil;

static void SCIResetForNewVideo(NSString *videoID) {
    sciCurrentVideoID = [videoID copy];
    sciSegments = nil;
    sciSkipped = [NSMutableSet set];
}

/// The video's identifier, whatever this build happens to call it.
///
/// A chain rather than one selector: the object handed to the delegate is an id, its
/// class is not declared here, and the accessor has carried more than one name across
/// versions. respondsToSelector first, always -- sending a selector an object does not
/// implement is exactly what crashed 0.1.1.
static NSString *SCIVideoIDFrom(id video) {
    if (!video) return nil;

    for (NSString *name in @[@"videoID", @"videoId", @"currentVideoID", @"identifier"]) {
        SEL selector = NSSelectorFromString(name);
        if (![video respondsToSelector:selector]) continue;

        id value = ((id (*)(id, SEL))objc_msgSend)(video, selector);
        if ([value isKindOfClass:[NSString class]] && ((NSString *)value).length) {
            return value;
        }
    }
    return nil;
}


// MARK: - The notice

///
/// A line saying what was skipped, with an undo.
///
/// Frame-based, deliberately. The layout engine took this tweak down twice, and a label
/// and a button in a rounded box need no constraints at all -- the arithmetic is three
/// lines and it cannot be unsatisfiable.
///
@interface SCISponsorNotice : UIView
+ (void)showCategory:(NSString *)category undo:(void (^)(void))undo;
@end

@implementation SCISponsorNotice {
    void (^_undo)(void);
}

static __weak SCISponsorNotice *sciVisibleNotice = nil;

+ (void)showCategory:(NSString *)category undo:(void (^)(void))undo {
    if (!SCIPrefEnabled(SCIPrefSBNotice)) return;

    UIWindow *host = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { host = window; break; }
        }
        if (host) break;
    }
    if (!host) return;

    [sciVisibleNotice removeFromSuperview];

    CGFloat width = MIN(host.bounds.size.width - 32, 340);
    CGFloat height = 44;

    SCISponsorNotice *notice = [[SCISponsorNotice alloc] initWithFrame:CGRectMake(
        (host.bounds.size.width - width) / 2,
        host.safeAreaInsets.top + 12,
        width, height)];
    notice->_undo = [undo copy];
    notice.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    notice.layer.cornerRadius = 14;
    notice.layer.cornerCurve = kCACornerCurveContinuous;
    notice.alpha = 0;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, width - 90, height)];
    label.text = [NSString stringWithFormat:SCILocalized(@"sb_skipped_format"),
        [SCIYTSponsorClient displayNameForCategory:category]];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.textColor = UIColor.whiteColor;
    [notice addSubview:label];

    UIButton *undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    undoButton.frame = CGRectMake(width - 76, 0, 66, height);
    [undoButton setTitle:SCILocalized(@"sb_undo") forState:UIControlStateNormal];
    [undoButton setTitleColor:[UIColor colorWithRed:1.0 green:0.28 blue:0.38 alpha:1.0]
                     forState:UIControlStateNormal];
    undoButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [undoButton addTarget:notice action:@selector(undoTapped)
         forControlEvents:UIControlEventTouchUpInside];
    [notice addSubview:undoButton];

    [host addSubview:notice];
    sciVisibleNotice = notice;

    [UIView animateWithDuration:0.2 animations:^{
        notice.alpha = 1;
    }];

    // Four seconds: long enough to read and reach the undo, short enough not to sit over
    // the video.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (notice.superview) [notice dismiss];
    });
}

- (void)undoTapped {
    if (_undo) _undo();
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end


// MARK: - The player

%hook YTPlayerViewController

- (void)playbackController:(id)controller
           didActivateVideo:(id)video
           withPlaybackData:(id)playbackData {
    %orig;

    if (!SCIPrefEnabled(SCIPrefSponsorBlock)) return;

    NSString *videoID = SCIVideoIDFrom(video);
    if (!videoID.length) {
        SCILogV(@"sponsorblock: could not read a video id from %@", [video class]);
        return;
    }

    if ([videoID isEqualToString:sciCurrentVideoID] && sciSegments) return;

    SCIResetForNewVideo(videoID);

    // Captured by value: by the time this returns, the user may well be on a different
    // video, and applying one video's segments to another would skip at random.
    NSString *requested = [videoID copy];

    [SCIYTSponsorClient segmentsForVideo:videoID
                             completion:^(NSArray<SCISponsorSegment *> *segments) {
        if (![requested isEqualToString:sciCurrentVideoID]) {
            SCILogV(@"sponsorblock: reply arrived for a video no longer playing");
            return;
        }
        sciSegments = segments;
    }];
}

- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)change {
    %orig;

    if (!SCIPrefEnabled(SCIPrefSponsorBlock) || !sciSegments.count) return;

    NSTimeInterval now = self.currentVideoMediaTime;
    if (!isfinite(now) || now < 0) return;

    for (SCISponsorSegment *segment in sciSegments) {
        if (now < segment.start || now >= segment.end) continue;
        if ([sciSkipped containsObject:segment.uuid]) continue;

        // A segment shorter than a second is not worth a jump: the seek itself costs
        // about that much, so skipping would be slower than watching it.
        if (segment.end - segment.start < 1.0) {
            [sciSkipped addObject:segment.uuid];
            continue;
        }

        [sciSkipped addObject:segment.uuid];

        SCILogV(@"sponsorblock: skipping %@ (%.1f → %.1f)",
                segment.category, segment.start, segment.end);

        [self seekToTime:segment.end];

        NSTimeInterval back = segment.start;
        __weak __typeof(self) weakSelf = self;
        [SCISponsorNotice showCategory:segment.category undo:^{
            // Back to where the skip started, and the segment stays marked as done so
            // the next time change does not immediately jump forward again.
            [weakSelf seekToTime:back];
        }];

        return;
    }
}

%end
