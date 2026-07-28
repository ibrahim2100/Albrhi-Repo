#import <objc/runtime.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Keeps messages that other people unsend — beta.
///
/// Three earlier attempts missed because they were on the wrong side of the wire.
/// Reading the class metadata out of both tested binaries settles where this
/// actually happens.
///
///   IGDirectMessageOutgoingUpdateRemoveMessagesMutationProcessor
///       an unsend *this device* performs, on its way to the server. Blocking it
///       would stop your own unsend reaching anyone — the message would stay on the
///       recipient's phone. Deliberately not hooked.
///
///   IGDirectCacheUpdatesApplicator -_applyThreadUpdates:…
///       where updates arriving *from* the server are applied to the local cache.
///       Someone else's unsend lands here. This is the one.
///
/// The shape is plain: the applicator is handed thread updates, each an
/// IGDirectThreadUpdate carrying a `_messageUpdate`, which is an IGDirectMessageUpdate
/// — a variant object whose fields are prefixed by case, so a removal is
/// `_removeMessages_messageKeys` with `_removeMessages_reason`. Emptying that key
/// list leaves the update to remove nothing, and touches no other case, so read
/// state, edits and reactions travel exactly as before. That separation is what the
/// very first version of this feature lacked, back when it blocked a whole realtime
/// path and left read messages showing as unread.
///
/// Both selector shapes are hooked: the newer build takes a third argument. Each
/// build has one of them, and a hook for a method a build lacks is never called.
///
/// The applicator and the ivar names came from RyukGram
/// (github.com/faroukbmiled/RyukGram, GPLv3), which references both selectors and
/// both ivars; the code here is Albrhi's own.
///
/// Beta, and off by default: pull-to-refresh in the inbox reloads threads from the
/// server, so a message kept only on this device goes with the refresh.
///

static BOOL SCIWantsToKeepUnsent(void) {
    return [SCIUtils getBoolPref:@"keep_unsent_messages"];
}

/// Empties one message update's removal list. Returns how many keys it dropped.
static NSInteger SCIDefuseMessageUpdate(id messageUpdate) {
    if (!messageUpdate) return 0;

    Ivar keysIvar = class_getInstanceVariable([messageUpdate class], "_removeMessages_messageKeys");
    if (!keysIvar) return 0;

    id keys = object_getIvar(messageUpdate, keysIvar);
    if (![keys isKindOfClass:[NSArray class]] || [(NSArray *)keys count] == 0) return 0;

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

    // KVC rather than a raw ivar write, so the assignment is ARC-correct. The key
    // maps to _removeMessages_messageKeys, which the guard above proved is there.
    @try {
        [messageUpdate setValue:@[] forKey:@"removeMessages_messageKeys"];
    } @catch (__unused id error) {
        return 0;
    }

    [SCIDiagnostics recordUnsendKeptWithReason:reason messageCount:count];
    SCILogV(@"[Albrhi] Held back an unsend of %ld message(s), reason %ld", (long)count, (long)reason);

    return count;
}

/// Walks whatever the applicator was handed and defuses every removal in it.
/// Shallow on purpose: the real shape is a collection of IGDirectThreadUpdate, each
/// with one message update, and this runs on every batch of updates that arrives.
static void SCIDefuseThreadUpdates(id updates, NSInteger depth) {
    if (!updates || depth > 3) return;

    if ([updates isKindOfClass:[NSArray class]] || [updates isKindOfClass:[NSSet class]]) {
        for (id element in updates) SCIDefuseThreadUpdates(element, depth + 1);
        return;
    }

    if ([updates isKindOfClass:[NSDictionary class]]) {
        for (id element in [(NSDictionary *)updates allValues]) SCIDefuseThreadUpdates(element, depth + 1);
        return;
    }

    Class cls = [updates class];

    // A message update itself, when one is handed over directly.
    if (class_getInstanceVariable(cls, "_removeMessages_messageKeys")) {
        SCIDefuseMessageUpdate(updates);
        return;
    }

    // The ordinary case: a thread update wrapping one message update.
    Ivar messageUpdate = class_getInstanceVariable(cls, "_messageUpdate");
    if (messageUpdate) {
        SCIDefuseMessageUpdate(object_getIvar(updates, messageUpdate));
        return;
    }

    // Otherwise the updates may arrive inside a wrapper rather than a bare
    // collection, so its own object fields are followed. Confined to Instagram's
    // direct-model classes and to the top two levels: this runs on every batch of
    // updates that arrives, and walking arbitrary objects would be both slow and a
    // good way to touch something that does not expect it.
    if (depth >= 2) return;

    NSString *name = NSStringFromClass(cls);
    if (![name hasPrefix:@"IGDirect"] && ![name hasPrefix:@"MD"]) return;

    unsigned int count = 0;
    Ivar *fields = class_copyIvarList(cls, &count);
    if (!fields) return;

    for (unsigned int i = 0; i < count; i++) {
        const char *type = ivar_getTypeEncoding(fields[i]);
        if (type && type[0] == '@') {
            SCIDefuseThreadUpdates(object_getIvar(updates, fields[i]), depth + 1);
        }
    }

    free(fields);
}

%hook IGDirectCacheUpdatesApplicator

// The older build.
- (void)_applyThreadUpdates:(id)updates completion:(id)completion {
    if (SCIWantsToKeepUnsent()) SCIDefuseThreadUpdates(updates, 0);

    %orig;
}

// The newer build, which carries a user-access argument as well.
- (void)_applyThreadUpdates:(id)updates completion:(id)completion userAccess:(id)userAccess {
    if (SCIWantsToKeepUnsent()) SCIDefuseThreadUpdates(updates, 0);

    %orig;
}

%end
