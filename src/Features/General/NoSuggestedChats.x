#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// Channels dms tab (header)
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