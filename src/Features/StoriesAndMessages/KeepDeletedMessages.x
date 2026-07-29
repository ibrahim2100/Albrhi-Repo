#import <objc/runtime.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Keeps messages that other people unsend — beta.
///
/// Instagram carries Direct on two stacks, and which one a chat uses is decided
/// server-side, so both have to be covered:
///
///   IGDirectCacheUpdatesApplicator -_applyThreadUpdates:…
///       the older path. Thread updates arrive, each an IGDirectThreadUpdate holding
///       an IGDirectMessageUpdate — a variant whose fields are prefixed by case, so a
///       removal is `_removeMessages_messageKeys`. Emptying that list leaves the
///       update removing nothing.
///
///   MDCoreDelta -match…deleteMessageDelta:…
///       the newer MSYS path. A delta object dispatches to one of five handler
///       blocks by case; substituting the delete-message handler means a delete
///       arriving from the server is simply never applied.
///
/// Both classes and every field named here are byte-identical across the two tested
/// Instagram builds, so one build covers both.
///
/// Deliberately NOT hooked: the outgoing mutation processor,
/// IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor. That is an unsend
/// this device performs on its way to the server, and blocking it would leave the
/// message sitting on the recipient's phone — worse than not having the feature.
///
/// Which path a given chat actually uses is reported to Diagnostics rather than
/// assumed, because an earlier version of this hooked one path, recorded nothing,
/// and gave no way to tell whether it had fired at all.
///
/// The applicator and the ivar names came from RyukGram
/// (github.com/faroukbmiled/RyukGram, GPLv3); the code here is Albrhi's own.
///
/// Beta, off by default: pull-to-refresh in the inbox reloads threads from the
/// server, so a message kept only on this device goes with the refresh.
///

static BOOL SCIWantsToKeepUnsent(void) {
    return [SCIUtils getBoolPref:@"keep_unsent_messages"];
}

// MARK: - Older path: thread updates

/// Empties one message update's removal list.
static void SCIDefuseMessageUpdate(id messageUpdate) {
    if (!messageUpdate) return;

    Ivar keysIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_messageKeys");
    if (!keysIvar) return;

    id keys = object_getIvar(messageUpdate, keysIvar);
    if (![keys isKindOfClass:[NSArray class]] || [(NSArray *)keys count] == 0) return;

    NSInteger count = (NSInteger)[(NSArray *)keys count];

    // Why the removal was issued. Reported rather than acted on: which value means
    // someone else's unsend is worth observing before anything depends on it. Read
    // straight from the ivar because it is a plain integer — both builds encode it
    // `q` — and object_getIvar would misread a scalar as an object pointer.
    NSInteger reason = -1;
    Ivar reasonIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_reason");
    if (reasonIvar) {
        char *base = (char *)(__bridge void *)messageUpdate;
        reason = *(NSInteger *)(base + ivar_getOffset(reasonIvar));
    }

    @try {
        [messageUpdate setValue:@[] forKey:@"removeMessages_messageKeys"];
    } @catch (__unused id error) {
        return;
    }

    [SCIDiagnostics recordUnsendKeptWithReason:reason messageCount:count];
    SCILogV(@"[Albrhi] Held back an unsend of %ld message(s), reason %ld", (long)count, (long)reason);
}

/// Walks what the applicator was handed. Deliberately narrow: collections, a thread
/// update's one message update, or a message update itself. An earlier version also
/// followed every object-typed ivar of anything Instagram-shaped, which meant reading
/// arbitrary ivars on every batch of updates — a good way to touch something that
/// does not survive being read, and the likely cause of a crash around GIFs.
static void SCIDefuseThreadUpdates(id updates, NSInteger depth) {
    if (!updates || depth > 2) return;

    if ([updates isKindOfClass:[NSArray class]] || [updates isKindOfClass:[NSSet class]]) {
        for (id element in updates) SCIDefuseThreadUpdates(element, depth + 1);
        return;
    }

    if ([updates isKindOfClass:[NSDictionary class]]) {
        for (id element in [(NSDictionary *)updates allValues]) SCIDefuseThreadUpdates(element, depth + 1);
        return;
    }

    Class cls = [updates class];

    if (class_getInstanceVariable(cls, "_removeMessages_messageKeys")) {
        SCIDefuseMessageUpdate(updates);
        return;
    }

    Ivar messageUpdate = class_getInstanceVariable(cls, "_messageUpdate");
    if (messageUpdate) {
        SCIDefuseMessageUpdate(object_getIvar(updates, messageUpdate));
        return;
    }

    // A wrapper holding the updates rather than being them. Named fields only, and
    // only these three: an earlier version followed every object field of anything
    // Instagram-shaped, on every batch, which was slow and the likely cause of a
    // crash around GIFs. Naming them keeps the reach without the risk.
    for (NSString *field in @[@"_threadUpdates", @"_updates", @"_deltas"]) {
        Ivar ivar = class_getInstanceVariable(cls, field.UTF8String);
        if (ivar) SCIDefuseThreadUpdates(object_getIvar(updates, ivar), depth + 1);
    }
}

// MARK: - The realtime channel

// Where an unsend actually arrives.
//
// Everything before this hooked IGDirectCacheUpdatesApplicator — the cache's own
// applicator — and Diagnostics kept reporting nothing held back, because a message
// someone else unsends does not come through the cache. It comes down Instagram's
// realtime channel, Iris, and that has its own applicator with a one-argument apply.
// The class and the signature are identical on both tested builds.
//
// The earliest version of this feature, back in 3.1, hooked IGDirectRealtimeIrisThreadDelta
// — the right channel, the wrong method. Disabling it moved the search away from the
// channel entirely, and three attempts were spent on the wrong side of it.
//
// Regram hooks both applicators and reads the same two ivars, which is what pointed
// back here.
%hook IGDirectRealtimeIrisDeltaApplicator

- (void)_applyThreadUpdates:(id)updates {
    if (SCIWantsToKeepUnsent()) {
        [SCIDiagnostics recordUnsendPath:@"iris applyThreadUpdates" detail:NSStringFromClass([updates class])];
        SCIDefuseThreadUpdates(updates, 0);
    }

    %orig;
}

%end

%hook IGDirectCacheUpdatesApplicator

// The older build.
- (void)_applyThreadUpdates:(id)updates completion:(id)completion {
    if (SCIWantsToKeepUnsent()) {
        [SCIDiagnostics recordUnsendPath:@"applyThreadUpdates" detail:NSStringFromClass([updates class])];
        SCIDefuseThreadUpdates(updates, 0);
    }

    %orig;
}

// The newer build, which carries a user-access argument as well.
- (void)_applyThreadUpdates:(id)updates completion:(id)completion userAccess:(id)userAccess {
    if (SCIWantsToKeepUnsent()) {
        [SCIDiagnostics recordUnsendPath:@"applyThreadUpdates+access" detail:NSStringFromClass([updates class])];
        SCIDefuseThreadUpdates(updates, 0);
    }

    %orig;
}

%end

// MARK: - Newer path: MSYS deltas

%hook MDCoreDelta

// The delta dispatches to whichever of these five handlers matches its case.
// Replacing the delete-message handler with one that only records means a delete
// arriving from the server is never applied, while every other case is passed
// through untouched — reactions, new messages and thread deletes all behave.
- (void)matchAddMessageDelta:(id)addMessage
           deleteThreadDelta:(id)deleteThread
         createReactionDelta:(id)createReaction
          deleteMessageDelta:(id)deleteMessage
         deleteReactionDelta:(id)deleteReaction {

    if (!SCIWantsToKeepUnsent() || !deleteMessage) {
        %orig;
        return;
    }

    void (^swallow)(id) = ^(__unused id delta) {
        [SCIDiagnostics recordUnsendPath:@"MSYS deleteMessageDelta" detail:@"held back"];
        SCILogV(@"[Albrhi] Held back an MSYS message delete");
    };

    %orig(addMessage, deleteThread, createReaction, swallow, deleteReaction);
}

%end
