#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

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
/// The class was identified from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3),
/// a fellow SCInsta fork; the mechanism here is Albrhi's own.
///
/// The first attempt at this hooked the right class and still did nothing, because
/// it wrote to `removeMessages_messageKeys` — a name taken from a string in the
/// binary that turned out to belong to something else. Reading the class's real ivar
/// list gives `_messageKeys`, and the wrong key threw an exception the @try quietly
/// swallowed, so the feature had never once run. The reason is the second ivar,
/// `_reason`, an integer distinguishing one kind of removal from another; it is
/// reported to Diagnostics so which value means what can be settled by observation
/// rather than assumed.
///
/// Beta, and off by default: pull-to-refresh in the inbox reloads threads from the
/// server, so anything kept only on this device goes with the refresh.
///

%hook IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor

- (id)initWithDirectRepo:(id)repo
               networker:(id)networker
                threadId:(id)threadId
             messageKeys:(id)messageKeys
                  reason:(NSInteger)reason
            dataProvider:(id)dataProvider {

    id processor = %orig;

    if (!processor || ![SCIUtils getBoolPref:@"keep_unsent_messages"]) {
        return processor;
    }

    NSInteger removed = [messageKeys isKindOfClass:[NSArray class]] ? (NSInteger)[(NSArray *)messageKeys count] : 0;

    // Empty the key list so the processor has nothing left to remove. KVC assigns
    // through the _messageKeys ivar under ARC, which a raw ivar write would not do
    // safely. Still wrapped: a build that renames the ivar should no-op, not crash.
    @try {
        [processor setValue:@[] forKey:@"messageKeys"];
    } @catch (__unused id error) {
        removed = -1;
    }

    [SCIDiagnostics recordUnsendKeptWithReason:reason messageCount:removed];

    return processor;
}

%end
