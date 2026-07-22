#import "../../Utils.h"
#import "../../InstagramHeaders.h"

///
/// Keeps messages other people unsend.
///
/// Restored from this project's own history — it was dropped in 3.1 along with a
/// batch of features that did not work, but the mechanism itself is sound: both
/// removal paths are passed a nil message id, so the deletion finds nothing to
/// remove and the message stays.
///
/// One honest limit, stated in the setting: pull-to-refresh in the DM inbox
/// reloads threads from the server, and anything preserved only on this device
/// disappears with it.
///

%hook IGDirectRealtimeIrisThreadDelta
+ (id)removeItemWithMessageId:(id)arg1 {
    if ([SCIUtils getBoolPref:@"keep_deleted_message"]) {
        arg1 = NULL;
    }

    return %orig(arg1);
}
%end

%hook IGDirectMessageUpdate
+ (id)removeMessageWithMessageId:(id)arg1{
    if ([SCIUtils getBoolPref:@"keep_deleted_message"]) {
        arg1 = NULL;
    }
    
    return %orig(arg1);
}
%end