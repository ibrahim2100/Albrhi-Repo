#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SCITWInlineButton.h"
#import "SCITWMedia.h"
#import "SCITWDownload.h"
#import "SCITWStatusButton.h"
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

///
/// What actually happened, for the report.
///
/// "The button did not appear" had four explanations that look identical from outside the
/// phone: the class is not in this build, the hook attached but the model never arrived,
/// the model arrived and yielded no media, or the button was placed and is behind
/// something. The report said nothing about any of it, so a device report could not
/// distinguish them and neither could I -- which is the failure mode this project has paid
/// for more than any other, and it was reintroduced here with no counter at all.
///
/// Four integers. They cost nothing and they answer the question in one round trip.
///
static BOOL sciClassPresent = NO;
static BOOL sciHookAttached = NO;
static NSUInteger sciModelsSeen = 0;
static NSUInteger sciItemsResolved = 0;
static NSUInteger sciButtonsPlaced = 0;

NSString *SCITWInlineButtonReport(void) {
    if (!sciClassPresent) return @"T1InlineMediaView is not in this build";
    if (!sciHookAttached) return @"T1InlineMediaView found, hook not installed";

    return [NSString stringWithFormat:
        @"%lu models, %lu with media, %lu buttons placed",
        (unsigned long)sciModelsSeen, (unsigned long)sciItemsResolved,
        (unsigned long)sciButtonsPlaced];
}

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

    // Counted, and nothing else.
    //
    // This is what the report was for and what it settled: twenty-five models arrived here
    // and not one of them yielded media. So the model on this view is not the one that
    // knows -- the tweet's is, two views up -- and asking this one was the whole reason a
    // button never appeared. The placement below does not consult it at all.
    sciModelsSeen++;

    id entity = SCITWEntityFromViewModel(viewModel);
    if (entity && [SCITWMedia itemForEntity:entity]) sciItemsResolved++;
}

- (void)didMoveToWindow {
    %orig;

    // The button goes on **this** view, which is the video.
    //
    // That is the whole of what the owner asked for: a button inside the picture, there
    // while swiping from one video to the next, rather than one bolted to the corner of a
    // timeline cell. T1InlineMediaView is the surface X shows every video and photo in --
    // timeline, tweet detail, the fullscreen viewer, a quoted post, a DM -- so a button on
    // it is inside the video wherever the video is.
    //
    // What to save is searched for upward from here, because this view's own model answers
    // nothing. The shared placement takes the two separately for exactly that reason.
    SCITWAddSaveButtonSoon(self, self);
    sciButtonsPlaced++;
}

%end

%end

void SCITWInstallInlineButton(void) {
    sciClassPresent = (NSClassFromString(@"T1InlineMediaView") != nil);

    if (!NSClassFromString(@"T1InlineMediaView")) {
        SCILogV(@"T1InlineMediaView is not in this build — no inline button");
        return;
    }

    %init(InlineButton);
    sciHookAttached = YES;
    SCILogV(@"inline download button attached");
}
