#import "../../Utils.h"
#import "../../InstagramHeaders.h"

///
/// Keeps messages that get unsent — beta.
///
/// The first version of this nulled the message id on the realtime Iris delta
/// (-removeItemWithMessageId:). That path is gone in current Instagram, and on the
/// build it existed for it also carried read-state, so blocking it made read
/// messages show as unread again. It was disabled for exactly that reason.
///
/// Current Instagram removes an unsent message through a dedicated processor,
/// IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor, built with the
/// keys of the messages to drop. Because that class does one thing — remove
/// messages — clearing its key list keeps the message without touching read-state,
/// which lives on an entirely different path. That was the missing separation.
///
/// The target class and its `_removeMessages_messageKeys` store were identified
/// from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3), a fellow SCInsta fork;
/// the mechanism here is Albrhi's own. The class is bound by name at load, so a
/// build without it simply does nothing rather than failing.
///
/// Beta, and off by default: the exact behaviour still wants confirming on device
/// through Settings → Diagnostics, and pull-to-refresh in the inbox reloads threads
/// from the server, so anything kept only on this device goes with the refresh.
///

%hook IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor

- (id)initWithDirectRepo:(id)repo
               networker:(id)networker
                threadId:(id)threadId
             messageKeys:(id)messageKeys
                  reason:(id)reason
            dataProvider:(id)dataProvider {

    id processor = %orig;

    if (processor && [SCIUtils getBoolPref:@"keep_unsent_messages"]) {
        // Empty the key list so the processor has nothing to remove. KVC finds the
        // _removeMessages_messageKeys ivar by name and assigns it under ARC, which a
        // raw ivar write would not do safely. Wrapped, because a build that renames
        // the store must not crash — it just means the feature no-ops there.
        @try {
            [processor setValue:@[] forKey:@"removeMessages_messageKeys"];
        } @catch (__unused id error) {}
    }

    return processor;
}

%end
