#import <substrate.h>
#import <objc/runtime.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Watches stories without telling their author.
///
/// The distinction that matters here, and that the previous version got wrong: a
/// story being *seen* is two separate things. Instagram keeps a local record — which
/// is what greys out the ring and stops a story coming back round — and it uploads a
/// receipt, which is what the author sees. Only the second one is anybody else's
/// business.
///
/// The version before this emptied IGStorySeenState as it was built. That object
/// backs both jobs, so it silenced the author *and* wiped the local record, which is
/// why stories kept reappearing until the eye button was pressed. Nothing is done to
/// it now; the local record fills exactly as Instagram intends.
///
/// The upload is blocked instead, at each build's own chokepoint:
///
///   IGStorySeenStateUploader -networker        both builds — the request has no
///                                             networker to go out on
///   IGStoryPendingSeenStateStore -_uploadSeenState:   the newer build's Swift store,
///                                             hooked by mangled name
///
/// Both were found by reading the class metadata out of the two tested binaries. The
/// pending store keeps its queue either way, so nothing downstream is left holding a
/// half-built object.
///

/// Set by the eye button in StorySeenButton.x. While true the receipt is let
/// through, so the story being watched right now does register with its author.
extern BOOL storySeenOverrideEnabled;

/// Whether the receipt should be blocked right now.
static BOOL SCIShouldBlockSeenReceipt(void) {
    if (![SCIUtils getBoolPref:@"no_seen_receipt"]) return NO;

    return !storySeenOverrideEnabled;
}

// MARK: - The uploader's way out

%hook IGStorySeenStateUploader

- (id)networker {
    if (!SCIShouldBlockSeenReceipt()) {
        return %orig;
    }

    [SCIDiagnostics recordStorySeenIntercept];
    SCILogV(@"[Albrhi] Withheld the networker a story seen receipt needed");

    return nil;
}

%end

// MARK: - The newer build's Swift store

// -_uploadSeenState: is where the newer build hands a batch of seen state off to be
// sent. Swallowing it leaves the batch collected locally and unsent. Bound by
// mangled name because Logos cannot name a Swift class, and skipped where the method
// is absent rather than added as one nothing calls.
static void (*orig_uploadSeenState)(id, SEL, id);

static void sci_uploadSeenState(id self, SEL _cmd, id seenState) {
    if (SCIShouldBlockSeenReceipt()) {
        [SCIDiagnostics recordStorySeenIntercept];
        SCILogV(@"[Albrhi] Swallowed a story seen upload");
        return;
    }

    if (orig_uploadSeenState) orig_uploadSeenState(self, _cmd, seenState);
}

%ctor {
    @autoreleasepool {
        Class store = objc_getClass("_TtC26IGStoryPendingSeenStateKit28IGStoryPendingSeenStateStore");
        SEL upload = NSSelectorFromString(@"_uploadSeenState:");

        if (store && class_getInstanceMethod(store, upload)) {
            MSHookMessageEx(store, upload, (IMP)sci_uploadSeenState, (IMP *)&orig_uploadSeenState);
        }
    }
}
