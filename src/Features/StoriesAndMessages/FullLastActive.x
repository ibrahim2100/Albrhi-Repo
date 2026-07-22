#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../General/SCIDateFormat.h"

///
/// Shows when someone was last active as a real date instead of "Active 2h ago".
///
/// The subtitle is rendered through IGDirectLeftAlignedTitleView, and the date it
/// came from is asked of the view model first. Instagram has used more than one
/// name for it, so each is tried; failing that the wording is read back, which is
/// less precise but still better than nothing.
///
/// The string itself comes from SCIDateFormat rather than a fixed pattern, so this
/// obeys whatever the user chose under Appearance — the same format their feed
/// timestamps use, rather than a second, inconsistent one.
///
/// Hook points identified from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3),
/// a fellow SCInsta fork.
///

static NSDate *SCILastActiveDate(id viewModel, NSString *currentText) {
    if (viewModel) {
        for (NSString *key in @[@"lastActiveDate", @"lastActive", @"activeDate"]) {
            @try {
                id value = [viewModel valueForKey:key];
                if ([value isKindOfClass:[NSDate class]]) return value;

                // Stored as Unix seconds in some builds.
                if ([value isKindOfClass:[NSNumber class]]) {
                    double seconds = [value doubleValue];
                    if (seconds > 1000000000.0 && seconds < 4000000000.0) {
                        return [NSDate dateWithTimeIntervalSince1970:seconds];
                    }
                }
            } @catch (__unused id e) {}
        }
    }

    // Nothing on the model: recover what the wording implies. "Active 8m ago"
    // pins the minute only roughly, which is why the model is asked first.
    return [SCIDateFormat dateFromRelativeText:currentText];
}

/// Rewrites whichever subtitle label this build is using.
static void SCIUpdateLastActive(UIView *titleView, id viewModel) {
    if (![SCIUtils getBoolPref:@"dm_full_last_active"]) return;

    for (NSString *key in @[@"subtitleLabel", @"_subtitleView", @"_transitionalSubtitleLabel"]) {
        UILabel *label = nil;
        @try { label = [titleView valueForKey:key]; } @catch (__unused id e) { continue; }

        if (![label isKindOfClass:[UILabel class]] || !label.text.length) continue;

        // Only a presence line is ours to rewrite; a username or typing indicator
        // is left exactly as Instagram wrote it.
        if (![SCIDateFormat isRelativeTimestamp:label.text] &&
            [label.text rangeOfString:@"ctive" options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }

        NSDate *date = SCILastActiveDate(viewModel, label.text);
        if (!date) continue;

        NSString *formatted = [SCIDateFormat stringForDate:date original:label.text];
        if (formatted.length) label.text = formatted;
    }
}

%hook IGDirectLeftAlignedTitleView

- (void)setTitleViewModel:(id)viewModel {
    %orig;
    SCIUpdateLastActive(self, viewModel);
}

// The subtitle is re-applied as the header animates in, which would otherwise
// put Instagram's own wording straight back.
- (void)animationCoordinatorDidUpdate:(id)coordinator {
    %orig;

    id viewModel = nil;
    @try { viewModel = [self valueForKey:@"titleViewModel"]; } @catch (__unused id e) {}

    SCIUpdateLastActive(self, viewModel);
}

%end
