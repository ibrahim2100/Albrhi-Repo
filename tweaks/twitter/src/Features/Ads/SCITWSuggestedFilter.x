#import <UIKit/UIKit.h>
#import "SCITWSuggestedFilter.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// Hidden on bind, shown on bind -- the same rule the promoted-tweet filter already
/// depends on, for the same reason: a card view is reused, and the same instance that
/// hid one suggestion is handed a different one on the very next scroll. Both branches of
/// the condition write `.hidden`, not only the one that hides something.
///

@interface T1UserRecommendationView : UIView
- (void)setAccount:(id)account;
@end

static BOOL sciSuggestedClassPresent = NO;
static NSUInteger sciSuggestedHidden = 0;

%group SuggestedFilter

%hook T1UserRecommendationView

- (void)setAccount:(id)account {
    %orig;

    BOOL hide = [[NSUserDefaults standardUserDefaults] boolForKey:SCIPrefHideSuggested];
    self.hidden = hide;
    if (hide) sciSuggestedHidden++;
}

%end

%end


NSString *SCITWSuggestedFilterReport(void) {
    if (!sciSuggestedClassPresent) return @"T1UserRecommendationView not in this build";
    return [NSString stringWithFormat:@"T1UserRecommendationView hooked · %lu hidden",
            (unsigned long)sciSuggestedHidden];
}

void SCITWInstallSuggestedFilter(void) {
    sciSuggestedClassPresent = (NSClassFromString(@"T1UserRecommendationView") != nil);
    if (!sciSuggestedClassPresent) {
        SCILogV(@"T1UserRecommendationView not in this build -- no suggested-account filter");
        return;
    }

    %init(SuggestedFilter);
    SCILogV(@"suggested-account filter attached");
}
