#import "SCITWMedia.h"
#import "SCITWMediaHooks.h"
#import "TwitterHeaders.h"
#import "SCILog.h"

///
/// Two hooks, both on the model, neither on a view.
///
/// `-initWithEntityMedia:` is where a fresh wrapper is built and `-setMediaEntity:` is
/// where an existing one is pointed at different media -- which is what a reused timeline
/// cell does, so a hook on only the initialiser sees the first screenful and then nothing.
/// Both are here for the same reason MLVideo's three initialisers are hooked in the YouTube
/// tweak: a list that is blank because a different route was taken looks exactly like a
/// list that is blank because the hook never attached, and telling those apart costs a
/// round trip to a device.
///

%group Media

%hook TFSTwitterMediaInfo

- (id)initWithEntityMedia:(id)media {
    id info = %orig;
    [SCITWMedia capture:media];
    return info;
}

- (void)setMediaEntity:(id)media {
    %orig;
    [SCITWMedia capture:media];
}

%end

%end


void SCITWInstallMediaHooks(void) {
    if (!NSClassFromString(@"TFSTwitterMediaInfo")) {
        SCILogV(@"TFSTwitterMediaInfo is not in this build — nothing to capture");
        return;
    }

    %init(Media);
    SCILogV(@"media capture attached");
}
