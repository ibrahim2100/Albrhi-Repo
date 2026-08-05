#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Compat/SCIResolve.h"

///
/// Hides the "Suggested" header in the chats tab.
///
/// The hook is in a %group, and that is the whole difference between this working and not.
/// IGDirectInboxHeaderSectionController was rewritten in Swift for Instagram 439, so its
/// runtime name now carries a module and a bare `%hook` by the plain name has matched
/// nothing since. Logos needs a class name at compile time, so the class is bound at load
/// instead, from whatever this build calls it.
///
/// Silent when it fails, which is why it went unnoticed for two Instagram versions: a hook
/// on a class that is not there is not an error, it is simply a feature that stopped.
///

%group SuggestedChatsHeader

%hook IGDirectInboxHeaderSectionController
- (id)viewModel {
    id vm = %orig;
    if ([[vm title] isEqualToString:@"Suggested"]) {

        if ([SCIUtils getBoolPref:@"no_suggested_chats"]) {
            SCILogV(@"[SCInsta] Hiding suggested chats (header: channels tab)");

            return nil;
        }

    }

    return vm;
}
%end

%end

%ctor {
    // Guarded, because %init on a nil class would hook nothing at an address of zero.
    Class header = SCIResolveClass(@"IGDirectInboxHeaderSectionController");
    if (header) {
        %init(SuggestedChatsHeader, IGDirectInboxHeaderSectionController = header);
    }
}
