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

// MARK: - What is being held

/// The message keys held back so far, and how many.
///
/// Blocking the removal is only half of it. The message stays because Instagram was
/// stopped from taking it away, but nothing here knows *which* messages those are —
/// so nothing can tell the user a refresh is about to lose them, and nothing can mark
/// them apart from ordinary messages later.
///
/// Regram keeps exactly this: a list of ids, their content, and a
/// -clearAllUnsentMessagesAfterRefresh, which is why it can warn before a reload.
/// This is the same idea, kept to what is needed and no more.
static NSMutableOrderedSet *sHeldKeys = nil;
static NSObject *sHeldLock = nil;

static NSObject *SCIHeldLock(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sHeldLock = [[NSObject alloc] init]; });
    return sHeldLock;
}

static void SCIRememberHeldKeys(NSArray *keys) {
    if (!keys.count) return;

    @synchronized (SCIHeldLock()) {
        if (!sHeldKeys) sHeldKeys = [NSMutableOrderedSet orderedSet];

        for (id key in keys) {
            NSString *text = [key isKindOfClass:[NSString class]] ? key : [key description];
            if (text.length) [sHeldKeys addObject:text];
        }

        // Bounded: a long session should not grow this without limit, and only the
        // recent ones matter for a warning about the refresh about to happen.
        while (sHeldKeys.count > 200) [sHeldKeys removeObjectAtIndex:0];
    }
}

NSInteger SCIHeldUnsendCount(void) {
    @synchronized (SCIHeldLock()) {
        return (NSInteger)sHeldKeys.count;
    }
}

void SCIClearHeldUnsends(void) {
    @synchronized (SCIHeldLock()) {
        [sHeldKeys removeAllObjects];
    }
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

    // Noted before the list is emptied, since afterwards there is nothing to note.
    SCIRememberHeldKeys(keys);

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

    // Fields found by declared type rather than by name.
    //
    // The name was the problem. This looked for `_messageUpdate`, which is what
    // IGDirectThreadUpdate calls it — but what actually arrives is
    // IGDirectCacheThreadUpdate, a Swift class whose field names are not ours to
    // guess. Its type encoding still says what it holds, and a field declared as an
    // IGDirect…MessageUpdate is the one worth following whatever it is called.
    //
    // Still narrow: only object fields whose type names a message or thread update
    // are read. The version that read every object field of anything Instagram-shaped
    // was slow and the likely cause of a crash around GIFs.
    BOOL followed = NO;

    unsigned int count = 0;
    Ivar *fields = class_copyIvarList(cls, &count);

    for (unsigned int i = 0; fields && i < count; i++) {
        const char *encoding = ivar_getTypeEncoding(fields[i]);
        if (!encoding || encoding[0] != '@') continue;

        NSString *type = @(encoding);
        if ([type rangeOfString:@"MessageUpdate"].location == NSNotFound
            && [type rangeOfString:@"ThreadUpdate"].location == NSNotFound) {
            continue;
        }

        followed = YES;
        SCIDefuseThreadUpdates(object_getIvar(updates, fields[i]), depth + 1);
    }

    if (fields) free(fields);
    if (followed) return;

    // Nothing matched, so report the object *and its object fields*. The class name
    // alone already moved this forward once — it named IGDirectCacheThreadUpdate
    // where IGDirectThreadUpdate was assumed — and if the search by type misses too,
    // the field list says what is actually in there instead of inviting another
    // guess. Names only, capped, and only when nothing matched, so it costs nothing
    // in the normal case.
    NSMutableArray<NSString *> *shape = [NSMutableArray array];

    unsigned int total = 0;
    Ivar *all = class_copyIvarList(cls, &total);

    for (unsigned int i = 0; all && i < total && shape.count < 6; i++) {
        const char *encoding = ivar_getTypeEncoding(all[i]);
        if (encoding && encoding[0] == '@') [shape addObject:@(ivar_getName(all[i]))];
    }
    if (all) free(all);

    [SCIDiagnostics recordUnsendPath:@"unmatched"
                              detail:[NSString stringWithFormat:@"%@ {%@}",
                                      NSStringFromClass(cls),
                                      [shape componentsJoinedByString:@","]]];
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

// MARK: - Warning before a refresh throws them away

// A pull-to-refresh reloads threads from the server, and anything kept only on this
// device goes with it. That was written in the setting's description and then left to
// happen silently, which is the worst of both: the user is told once, in settings,
// and never at the moment it matters.
//
// Regram guards the same moment — it has a reload alert and a
// -clearAllUnsentMessagesAfterRefresh — and that is what makes its version of this
// feature feel deliberate rather than fragile.
//
// The selector exists on the newer build only, so the older one refreshes as it
// always has. A warning on one build and not the other is not ideal; a warning
// nowhere is worse.
%hook IGDirectInboxViewController

// A plain function rather than a %new method: sending a message to the hooked class
// would need an @interface for it, since Logos only forward-declares what it hooks —
// the rule this project already wrote down after the same mistake.
static void SCIWarnAboutRefresh(void) {
    if (!SCIWantsToKeepUnsent() || SCIHeldUnsendCount() == 0) return;

    [SCIUtils showToastForDuration:2.4
                             title:SCILocalized(@"keep_unsent_refresh_warning")];

    // Cleared here rather than left to drift: after this refresh they are gone from
    // the chat, so continuing to count them would make the next warning a lie.
    SCIClearHeldUnsends();
}

// The newer build.
- (void)pullToRefreshIfPossible {
    SCIWarnAboutRefresh();

    %orig;
}

// The older build spells it with a leading underscore, which is why the warning never
// appeared there — the hook was attached to a name that build does not have.
- (void)_pullToRefreshIfPossible {
    SCIWarnAboutRefresh();

    %orig;
}

%end
