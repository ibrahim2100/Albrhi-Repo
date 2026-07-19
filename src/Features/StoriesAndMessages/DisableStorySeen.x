#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

/// Set by the eye button in StorySeenButton.x. While true the uploader is let
/// through, so the story currently being watched registers as seen.
extern BOOL storySeenOverrideEnabled;

/// Whether the seen receipt should be blocked right now.
static BOOL SCIShouldBlockSeenReceipt(void) {
    if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;

    return !storySeenOverrideEnabled;
}

%hook IGStorySeenStateUploader
- (id)initWithUserSessionPK:(id)arg1 networker:(id)arg2 {
    if (SCIShouldBlockSeenReceipt()) {
        [SCIDiagnostics recordStorySeenIntercept];
        NSLog(@"[Albrhi] Prevented story seen receipt from being sent");

        return nil;
    }

    return %orig;
}

- (id)networker {
    if (SCIShouldBlockSeenReceipt()) {
        [SCIDiagnostics recordStorySeenIntercept];
        NSLog(@"[Albrhi] Prevented story seen receipt from being sent");

        return nil;
    }

    return %orig;
}
%end
