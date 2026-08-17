#import "SCITTPrivacy.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCITTDiagnostics.h"

///
/// Three confirmed points where the app tells TikTok's own servers what was seen,
/// cross-validated between NA9 For TikTok and VibeTok -- both independently hook the
/// same three selectors, which is the same "two references agree" bar the rest of
/// this project holds a finding to before hooking it.
///
///   TTKStoryMarkReadService -markAsRead:               a story was opened
///   AWEIMMessageReadComponent -p_markReadSyncToServerWithMessage:
///                                                       a DM was read
///   TTKProfileViewsVisitor -reportProfileView /
///                          -p_shouldReportProfileView   a profile was visited
///
/// The message case is the one worth being careful about: TikTok keeps a *local*
/// mark-as-read selector, `-p_markMessageAsReadLocally:`, entirely separate from the
/// one that syncs it outward. Only the sync method is hooked here, left untouched
/// otherwise, so the conversation's own unread badge still clears normally on this
/// device -- the same distinction Instagram's own story-seen feature draws between a
/// local record and the receipt built from it.
///

@interface TTKStoryMarkReadService : NSObject
@end

@interface AWEIMMessageReadComponent : NSObject
@end

@interface TTKProfileViewsVisitor : NSObject
@end


%group Privacy

%hook TTKStoryMarkReadService

- (void)markAsRead:(id)story {
    if (!SCIPrefEnabled(SCIPrefPrivacy)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordBypassAnswer:@"story markAsRead withheld"];
}

%end

%hook AWEIMMessageReadComponent

- (void)p_markReadSyncToServerWithMessage:(id)message {
    if (!SCIPrefEnabled(SCIPrefPrivacy)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordBypassAnswer:@"message read-sync withheld"];
}

%end

%hook TTKProfileViewsVisitor

- (void)reportProfileView {
    if (!SCIPrefEnabled(SCIPrefPrivacy)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordBypassAnswer:@"profile view withheld"];
}

- (BOOL)p_shouldReportProfileView {
    if (!SCIPrefEnabled(SCIPrefPrivacy)) return %orig;
    [SCITTDiagnostics recordBypassAnswer:@"profile view withheld"];
    return NO;
}

%end

%end


void SCITTInstallPrivacy(void) {
    BOOL any = NO;

    if (NSClassFromString(@"TTKStoryMarkReadService")) any = YES;
    if (NSClassFromString(@"AWEIMMessageReadComponent")) any = YES;
    if (NSClassFromString(@"TTKProfileViewsVisitor")) any = YES;

    if (!any) {
        SCILogV(@"none of the three privacy-report classes are in this build");
        return;
    }

    %init(Privacy);
    SCILogV(@"privacy hooks attached");
}
