#import <UIKit/UIKit.h>
#import "SCITWInlineButton.h"
#import "SCITWMedia.h"
#import "SCITWStatusButton.h"
#import "Prefs.h"
#import "SCILog.h"

/// Declared, not merely hooked.
///
/// A `%hook` on a class with no `@interface` leaves Logos with only a forward declaration,
/// and `self` typed as a forward-declared class cannot be sent a message -- not even
/// `-respondsToSelector:`, which is why the build failed on the guard rather than on the
/// property. Declaring it a UIView subclass with the one method used gives the compiler the
/// type it needs.
@interface T1InlineMediaView : UIView
- (void)setViewModel:(id)viewModel;
@end

///
/// The button, on X's own video/photo view.
///
/// `T1InlineMediaView` is the surface every video and photo is shown in -- timeline, full
/// screen, quoted post, direct message. `SCITWPlaceSaveButton` (SCITWStatusButton.x) puts
/// the button directly on it at a fixed corner, which is what makes the button inside the
/// picture wherever the picture is.
///
/// This view's own `-viewModel` is not where the media comes from -- a device report
/// settled that: twenty-five models arrived and not one yielded media, because the model
/// here is the video's own, not the post's. `SCITWEntityFromViewModel` below exists only
/// to count that for the report; the real save target is resolved by
/// `SCITWPlaceSaveButton` walking upward until an ancestor's model answers.
///
/// **Placement triggers from `-setViewModel:`, not only from `-didMoveToWindow`.** A cell
/// scrolled out of view and back in during a timeline scroll is not removed from its window
/// and reinserted -- it stays resident and is *reused*, rebound to a new post through this
/// exact method, and `-didMoveToWindow` never fires again for it. That is why the button
/// used to appear on the first screenful of a scroll and nowhere after: everything past the
/// first reused batch of cells got no trigger at all. Opening a tweet worked regardless,
/// because pushing a new screen builds genuinely new views, which do enter a window.
/// `-setViewModel:` runs on first appearance and on every reuse alike -- the twenty-five
/// calls in that same report are exactly the proof.
///

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
/// **The fourth one is honest about what it counts.** Placement is deferred a turn of the
/// runloop -- SCITWAddSaveButtonSoon does not report back whether a button actually went
/// up -- so this file cannot know that synchronously. It used to increment on every
/// `-didMoveToWindow` regardless, which counts appearances of the view, not buttons, and a
/// report that says "buttons placed" when it means "times we asked" is the same overclaim
/// this project keeps writing rules against elsewhere. Named for what it is instead.
///
static BOOL sciClassPresent = NO;
static BOOL sciHookAttached = NO;
static NSUInteger sciModelsSeen = 0;
static NSUInteger sciItemsResolved = 0;
static NSUInteger sciPlacementAttempts = 0;

NSString *SCITWInlineButtonReport(void) {
    if (!sciClassPresent) return @"T1InlineMediaView is not in this build";
    if (!sciHookAttached) return @"T1InlineMediaView found, hook not installed";

    return [NSString stringWithFormat:
        @"%lu models, %lu with media, %lu placements attempted",
        (unsigned long)sciModelsSeen, (unsigned long)sciItemsResolved,
        (unsigned long)sciPlacementAttempts];
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


%group InlineButton

%hook T1InlineMediaView

- (void)setViewModel:(id)viewModel {
    %orig;

    // Counted, and now also the real trigger -- see the class doc above for why
    // -didMoveToWindow alone left every recycled cell in a timeline with no button.
    sciModelsSeen++;

    id entity = SCITWEntityFromViewModel(viewModel);
    if (entity && [SCITWMedia itemForEntity:entity]) sciItemsResolved++;

    SCITWAddSaveButtonSoon(self);
    sciPlacementAttempts++;
}

- (void)didMoveToWindow {
    %orig;

    // Kept as a second trigger, not the first any more.
    //
    // A view can in principle enter a window with its model already set and receive no
    // further -setViewModel: call before becoming visible -- rare, but a fallback that
    // costs one more dispatch is cheaper than a video with no button in the one case it
    // happens. SCITWPlaceSaveButton is idempotent either way: a button already there is
    // found by its tag and only refreshed, never duplicated.
    SCITWAddSaveButtonSoon(self);
    sciPlacementAttempts++;
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
