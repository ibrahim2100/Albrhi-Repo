#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITWInlineButton.h"
#import "SCITWMedia.h"
#import "SCITWDownload.h"
#import "Prefs.h"
#import "SCILog.h"

/// Declared, not merely hooked.
///
/// A `%hook` on a class with no `@interface` leaves Logos with only a forward declaration,
/// and `self` typed as a forward-declared class cannot be sent a message -- not even
/// `-respondsToSelector:`, which is why the build failed on the guard rather than on the
/// property. Declaring it a UIView subclass with the one method used gives the compiler the
/// type it needs; `-overlayChromesContainerView` is X's own, reached through this rather
/// than by a stringly-typed `-valueForKey:`.
@interface T1InlineMediaView : UIView
- (UIView *)overlayChromesContainerView;
- (void)setViewModel:(id)viewModel;
@end

///
/// The button, on X's own inline media view.
///
/// `T1InlineMediaView` is the surface every video and photo is shown in -- timeline, full
/// screen, quoted post, direct message. It already carries an overlay of chrome (the play
/// button, the audio toggle) in `overlayChromesContainerView`, and the button goes there so
/// it appears and disappears with the rest of the chrome rather than sitting on top of a
/// playing video forever.
///
/// The media comes from the view's own `-viewModel`. That object is one of several classes
/// depending on the surface, so the entity is reached by asking -- `-mediaEntity` directly,
/// or a media-info holder's `-mediaEntity` -- rather than by assuming one shape. A view
/// whose model yields no saveable entity gets no button, which is the same rule the list
/// uses and the reason a photo-only post does not sprout one.
///

static const void *kButtonKey = &kButtonKey;
static const void *kItemKey = &kItemKey;

/// The entity behind a view model, however that model is shaped.
///
/// `-mediaEntity` returns a TFSTwitterEntityMedia directly on the component models;
/// `-primaryMediaInfo` and `-mediaInfo` return a TFSTwitterMediaInfo, which has its own
/// `-mediaEntity`. Tried in that order, each guarded, so a model with none of them simply
/// produces nothing.
static id SCITWEntityFromViewModel(id viewModel) {
    if (!viewModel) return nil;

    if ([viewModel respondsToSelector:@selector(mediaEntity)]) {
        id entity = [viewModel performSelector:@selector(mediaEntity)];
        if (entity) return entity;
    }

    for (NSString *name in @[@"primaryMediaInfo", @"mediaInfo"]) {
        SEL selector = NSSelectorFromString(name);
        if (![viewModel respondsToSelector:selector]) continue;

        id info = [viewModel performSelector:selector];
        if ([info respondsToSelector:@selector(mediaEntity)]) {
            id entity = [info performSelector:@selector(mediaEntity)];
            if (entity) return entity;
        }
    }

    return nil;
}


@interface SCITWInlineButtonTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(UIButton *)button;
@end

@implementation SCITWInlineButtonTarget

+ (instancetype)shared {
    static SCITWInlineButtonTarget *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCITWInlineButtonTarget alloc] init]; });
    return shared;
}

- (void)tapped:(UIButton *)button {
    // The item is resolved at layout and kept on the button, not resolved on the tap: by
    // the time a video is tapped its view model may have been handed to a different post as
    // the cell is reused, and saving what is on screen now rather than what was under the
    // finger is the kind of bug that ships and is blamed on "it saved the wrong video".
    SCITWMediaItem *item = objc_getAssociatedObject(button, kItemKey);
    if (item) [SCITWDownload save:item];
}

@end


%group InlineButton

%hook T1InlineMediaView

- (void)setViewModel:(id)viewModel {
    %orig;

    // Resolved once, when the model is set, and remembered on the view. layoutSubviews runs
    // many times a second while a video plays and is the wrong place to be sending
    // messages down a model graph.
    id entity = SCITWEntityFromViewModel(viewModel);
    SCITWMediaItem *item = entity ? [SCITWMedia itemForEntity:entity] : nil;

    UIButton *button = objc_getAssociatedObject(self, kButtonKey);
    objc_setAssociatedObject(button, kItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // A reused cell that now holds a photo-only post, or no media, hides the button it was
    // given for a video. Left visible, it would offer to save the previous video from the
    // new post.
    button.hidden = (item == nil);
}

- (void)layoutSubviews {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefInlineButton]) return;

    UIView *container = nil;
    if ([self respondsToSelector:@selector(overlayChromesContainerView)]) {
        container = [self overlayChromesContainerView];
    }
    if (!container) container = self;

    UIButton *button = objc_getAssociatedObject(self, kButtonKey);
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;

        UIImage *icon = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];

        // A disc behind the glyph, so it reads on a bright frame of video as well as a dark
        // one -- the same reason X's own audio toggle has one.
        button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
        button.layer.cornerRadius = 15;
        button.layer.masksToBounds = YES;

        // The chrome fades with taps on the video; the button rides that container, so it
        // does not need its own show/hide. But it must not swallow the tap that toggles the
        // chrome elsewhere on the view -- only its own 30pt circle.
        [button addTarget:[SCITWInlineButtonTarget shared]
                   action:@selector(tapped:)
         forControlEvents:UIControlEventTouchUpInside];

        objc_setAssociatedObject(self, kButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [container addSubview:button];

        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:container.topAnchor constant:8],
            [button.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
            [button.widthAnchor constraintEqualToConstant:30],
            [button.heightAnchor constraintEqualToConstant:30],
        ]];

        SCITWMediaItem *item = objc_getAssociatedObject(button, kItemKey);
        button.hidden = (item == nil);
    }

    // Kept on top: X adds and removes chrome subviews as playback state changes, and a
    // button added once can end up behind the shaded overlay after a state change.
    [container bringSubviewToFront:button];
}

%end

%end


void SCITWInstallInlineButton(void) {
    if (!NSClassFromString(@"T1InlineMediaView")) {
        SCILogV(@"T1InlineMediaView is not in this build — no inline button");
        return;
    }

    %init(InlineButton);
    SCILogV(@"inline download button attached");
}
