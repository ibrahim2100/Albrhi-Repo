//
//  SCITTExtras.x
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SCITTExtras.h"
#import "../../Prefs.h"
#import "../../Diagnostics/SCITTDiagnostics.h"
#import "../../SCILog.h"
#import "../../Localization/SCILocalize.h"

///
/// **Where these came from, and what was measured before any of it was written.**
///
/// The three features exist in VibeTok, which is unlicensed and is read here for architecture only
/// -- never for code, the same line this project keeps for every unlicensed TikTok reference. What
/// its hook table gave was a list of *places to look*, and every one of them was then confirmed
/// against the real binary with tools/objc-classes.py before a line was written.
///
/// **That confirmation immediately corrected it.** VibeTok hooks `-isRecalled` on `TIMOMessage`;
/// **that selector does not exist in 46.4.0 at all** -- the property is `recalled` and its getter is
/// `-recalled`. A reference's selector is what worked for its author, not what is in front of you,
/// which is a rule this project has already paid for twice with `downloadAddr` and
/// `bestURLtoDownload`.
///
/// Confirmed on 46.4.0, and again on 45.7.0, so these are stable across two builds rather than
/// true of one:
///
///     AWEUserService              -maxLoginedAccounts        Q16@0:8
///     TIMOMessage                 -recalled                  B16@0:8
///     TTKProfileViewsPresenter    -model                     @16@0:8   (NSMutableArray)
///

@interface AWEUserService : NSObject
@end

@interface TIMOMessage : NSObject
@end

@interface TTKProfileViewsPresenter : NSObject
@end

static NSString *sciExtrasState = nil;
static NSUInteger sciVisitorsSeen = 0;

/// The messages whose sender took them back, by `serverMessageID`.
///
/// **The hook that hides the recall is also the only thing that knows one happened.** `%orig`
/// answers YES a moment before Albrhi answers NO, so the fact is there to be kept rather than
/// swallowed -- and keeping it is what lets the message be *marked* instead of quietly restored.
/// A message shown as though nothing happened is the tweak deciding something on the reader's
/// behalf without saying so, which is the same objection this project raised about a watch being
/// told it was up to date.
static NSMutableSet *sciRecalledIDs = nil;

/// What the content dictionary turned out to hold, recorded once, and which key was marked.
static NSString *sciContentKeys = nil;
static NSString *sciMarkedKey = nil;
static NSUInteger sciMarkedCount = 0;

/// Where the visitor log lives. TikTok's own defaults, because this runs inside TikTok and the log
/// is only ever read there and by Albrhi's own screen inside the same process.
static NSString *const kSCITTVisitorKey = @"albrhi_tt_visitors";

static BOOL SCITTEncodingMatches(Class cls, NSString *selectorName, NSString *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    return types && [expected isEqualToString:[NSString stringWithUTF8String:types]];
}

#pragma mark - The account limit

%group SCITTAccounts

%hook AWEUserService

- (unsigned long long)maxLoginedAccounts {
    if (!SCIPrefEnabled(SCIPrefUnlimitedAccounts)) return %orig;

    // Raised, not removed: the app asks how many are allowed and something downstream will size a
    // list from the answer. A number it can hold is a different thing from no answer at all.
    return 99;
}

%end
%end

#pragma mark - A message the sender took back

%group SCITTKeepRecalled

%hook TIMOMessage

- (BOOL)recalled {
    // Called once, on its own line, and the answer reused. `if (%orig)` shares its line with a
    // brace, which this Logos version cannot expand -- check.py caught it here, in code written by
    // the same hand that added the rule two days ago.
    BOOL recalled = %orig;

    if (!SCIPrefEnabled(SCIPrefKeepRecalled)) return recalled;

    if (recalled) {
        // Remembered before it is answered away. Ids only -- holding the message itself would keep
        // it alive past the conversation that made it.
        id identifier = [self respondsToSelector:@selector(serverMessageID)]
            ? ((id (*)(id, SEL))objc_msgSend)(self, @selector(serverMessageID)) : nil;

        if (identifier) {
            static dispatch_once_t once;
            dispatch_once(&once, ^{ sciRecalledIDs = [NSMutableSet set]; });
            @synchronized (sciRecalledIDs) { [sciRecalledIDs addObject:identifier]; }
        }
    }

    // The message is still here: TikTok received it, then received an instruction to hide it, and
    // hiding is done by the client. Nothing is fetched back from a server -- what is refused is the
    // instruction to stop showing what already arrived.
    return NO;
}

%end
%end

#pragma mark - Saying which ones were taken back

%group SCITTMarkRecalled

%hook TIMOMessage

- (id)content {
    id content = %orig;

    if (!SCIPrefEnabled(SCIPrefKeepRecalled)) return content;
    if (![content isKindOfClass:[NSDictionary class]]) return content;

    id identifier = [self respondsToSelector:@selector(serverMessageID)]
        ? ((id (*)(id, SEL))objc_msgSend)(self, @selector(serverMessageID)) : nil;
    if (!identifier) return content;

    BOOL recalled = NO;
    @synchronized (sciRecalledIDs ?: [NSMutableSet set]) {
        recalled = [sciRecalledIDs containsObject:identifier];
    }
    if (!recalled) return content;

    // Recorded once, so the next release can name the key instead of matching a shape.
    if (!sciContentKeys) {
        sciContentKeys = [[(NSDictionary *)content allKeys] componentsJoinedByString:@", "];
    }

    //
    // **The key is matched on its name, and the report says which one was taken.**
    //
    // The content dictionary's text key is not documented anywhere this project can read, and
    // guessing at a name is what `downloadAddr` and `bestURLtoDownload` already cost this tweak.
    // So the rule is narrow and visible: the first key whose own name contains "text", carrying a
    // string. If nothing matches, **nothing is marked** and the report carries every key there was
    // -- an honest miss that names the fix, rather than a mark placed on whatever happened to be a
    // string.
    //
    NSMutableDictionary *marked = [NSMutableDictionary dictionaryWithDictionary:content];
    NSString *chosen = nil;

    //
    // **`text` is the key, confirmed on a device rather than matched by shape.**
    //
    // The first version took the first key whose *name* contained "text", and said so on its own
    // row so the next release could name it exactly. A report came back reading `marked: 1 via key
    // text` -- so the exact key is tried first now, and the shape rule stays underneath it as the
    // fallback for a build that renames it. A measurement that arrives and is not used is a round
    // trip spent for nothing.
    //
    NSString *known = content[@"text"];
    if ([known isKindOfClass:[NSString class]]) {
        NSString *badge = SCILocalized(@"recalled_badge");
        if ([known hasPrefix:badge]) return content;

        marked[@"text"] = [badge stringByAppendingString:known];
        sciMarkedKey = @"text";
        sciMarkedCount++;
        return marked;
    }

    for (NSString *key in [(NSDictionary *)content allKeys]) {
        if (![key isKindOfClass:[NSString class]]) continue;
        if ([key rangeOfString:@"text" options:NSCaseInsensitiveSearch].location == NSNotFound)
            continue;

        NSString *value = content[key];
        if (![value isKindOfClass:[NSString class]]) continue;

        NSString *badge = SCILocalized(@"recalled_badge");
        if ([value hasPrefix:badge]) return content;   // already marked: idempotent by content

        marked[key] = [badge stringByAppendingString:value];
        chosen = key;
        break;
    }

    if (!chosen) return content;

    sciMarkedKey = chosen;
    sciMarkedCount++;

    // A copy is returned; TikTok's own dictionary is never written through. Same reason the
    // visitor list is not merged back into the array the app is about to draw.
    return marked;
}

%end
%end

#pragma mark - Who looked at the profile

%group SCITTVisitors

%hook TTKProfileViewsPresenter

- (id)model {
    id visitors = %orig;
    if (!SCIPrefEnabled(SCIPrefVisitorLog)) return visitors;

    //
    // **Recorded as they arrive, and never merged back into TikTok's own list.**
    //
    // The reference keeps its cache and hands a combined array back to the app, which is what makes
    // somebody who has since blocked you still appear in TikTok's own screen. That is not done
    // here: feeding objects the app did not create back into a list it is about to render is the
    // same shape of thing that crashed the Watch app -- a view told an item exists and reading
    // something out of it. Albrhi keeps its own record and shows it on its own screen instead.
    //
    // The effect a person actually asked for survives that: a visitor seen once is remembered, so a
    // block afterwards does not erase what was already delivered.
    //
    if (![visitors isKindOfClass:[NSArray class]] || ![visitors count]) return visitors;

    NSMutableArray *log = [NSMutableArray arrayWithArray:
        [[NSUserDefaults standardUserDefaults] arrayForKey:kSCITTVisitorKey] ?: @[]];

    for (id entry in (NSArray *)visitors) {
        // Only a description is kept -- a name and the moment it was seen. Holding TikTok's own
        // objects would keep them alive past the screen that made them, and a tweak that changes an
        // app's object lifetimes has stopped being an observer.
        NSString *name = [entry respondsToSelector:@selector(nickname)]
            ? [entry performSelector:@selector(nickname)] : nil;
        if (![name isKindOfClass:[NSString class]] || !name.length) continue;

        if ([log.firstObject isEqualToString:name]) continue;
        [log removeObject:name];
        [log insertObject:name atIndex:0];
        sciVisitorsSeen++;
    }

    // Bounded, because a log that grows without limit inside somebody's app is the thing this
    // project switched off in Albrhi NextUp.
    while (log.count > 200) [log removeLastObject];

    [[NSUserDefaults standardUserDefaults] setObject:log forKey:kSCITTVisitorKey];
    return visitors;
}

%end
%end

#pragma mark - Installation

NSArray<NSString *> *SCITTVisitorLog(void) {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kSCITTVisitorKey] ?: @[];
}

NSString *SCITTExtrasReport(void) {
    return [NSString stringWithFormat:
            @"%@; visitors remembered: %lu (%lu seen this launch); recalled seen: %lu, marked: %lu%@%@",
            sciExtrasState ?: @"not installed",
            (unsigned long)SCITTVisitorLog().count, (unsigned long)sciVisitorsSeen,
            (unsigned long)(sciRecalledIDs.count), (unsigned long)sciMarkedCount,
            sciMarkedKey ? [@" via key " stringByAppendingString:sciMarkedKey] : @"",
            sciContentKeys ? [@"; content keys: " stringByAppendingString:sciContentKeys] : @""];
}

//
// **Never reported as online.**
//
// Confirmed against this device's own 46.4.0 binary rather than against a reference tweak's list:
// four chokepoints on `AWEIMActivityStatusReportManager`, each with its encoding read before a hook
// was written. The two `-p_report…` calls are where a status actually leaves the phone; the two
// booleans above them are what decides whether it is worth sending. Refusing all four is the
// difference between "the report was suppressed once" and "there is nothing to suppress".
//
// This is the same shape as the three privacy switches already here: **a report is withheld from
// leaving the device, and the server is never told anything untrue.** Nothing here claims to be
// offline; it simply stops announcing.
//
%group SCITTHideOnline

%hook AWEIMActivityStatusReportManager

- (BOOL)p_enableReportOnlineStatus {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) return %orig;
    return NO;
}

- (BOOL)canFetchAsReportCurrentUserActivityStatus {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) return %orig;
    return NO;
}

- (void)p_reportActivityStatusIfNeededWithParams:(id)params {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"online status withheld (if-needed)"];
}

- (void)p_reportActivityStatusWithParams:(id)params {
    if (!SCIPrefEnabled(SCIPrefHideOnline)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"online status withheld"];
}

%end

%end

//
// **A video that has finished does not start again.**
//
// `-playerWillLoopPlaying:` is the app announcing that it is about to restart the clip, on the
// same `AWEFeedCellViewController` this tweak already holds for the model behind the download
// button -- so the class is confirmed twice over and the encoding was read before hooking.
//
// **Not calling through is the whole feature, and it is deliberately not "advance to the next
// video".** Those are different requests, and this project has already recorded what happens when
// a correct principle is applied one step further than it was asked for.
//
%group SCITTNoLoop

%hook AWEFeedCellViewController

- (void)playerWillLoopPlaying:(id)player {
    if (!SCIPrefEnabled(SCIPrefNoLoop)) {
        %orig;
        return;
    }
    [SCITTDiagnostics recordPrivacyAnswer:@"video loop refused"];
}

%end

%end

void SCITTInstallExtras(void) {
    NSMutableArray<NSString *> *installed = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];

    //
    // **Each of the three decides for itself.** A build missing one of these classes must install
    // the other two rather than stand down entirely -- a gate narrower than what it guards fails
    // silently in the direction of doing less, which this project has now written down twice.
    //
    Class accounts = NSClassFromString(@"AWEUserService");
    if (accounts && SCITTEncodingMatches(accounts, @"maxLoginedAccounts", @"Q16@0:8")) {
        %init(SCITTAccounts);
        [installed addObject:@"-maxLoginedAccounts"];
    } else {
        [skipped addObject:@"AWEUserService -maxLoginedAccounts"];
    }

    Class message = NSClassFromString(@"TIMOMessage");
    if (message && SCITTEncodingMatches(message, @"recalled", @"B16@0:8")) {
        %init(SCITTKeepRecalled);
        [installed addObject:@"-recalled"];
    } else {
        [skipped addObject:@"TIMOMessage -recalled"];
    }

    if (message && SCITTEncodingMatches(message, @"content", @"@16@0:8")) {
        %init(SCITTMarkRecalled);
        [installed addObject:@"-content (recalled mark)"];
    } else {
        [skipped addObject:@"TIMOMessage -content"];
    }

    Class online = NSClassFromString(@"AWEIMActivityStatusReportManager");
    if (online && SCITTEncodingMatches(online, @"p_enableReportOnlineStatus", @"B16@0:8")
               && SCITTEncodingMatches(online, @"p_reportActivityStatusWithParams:", @"v24@0:8@16")) {
        %init(SCITTHideOnline);
        [installed addObject:@"-p_report… (hide online)"];
    } else {
        [skipped addObject:@"AWEIMActivityStatusReportManager -p_report…"];
    }

    Class feedCell = NSClassFromString(@"AWEFeedCellViewController");
    if (feedCell && SCITTEncodingMatches(feedCell, @"playerWillLoopPlaying:", @"v24@0:8@16")) {
        %init(SCITTNoLoop);
        [installed addObject:@"-playerWillLoopPlaying: (no loop)"];
    } else {
        [skipped addObject:@"AWEFeedCellViewController -playerWillLoopPlaying:"];
    }

    Class presenter = NSClassFromString(@"TTKProfileViewsPresenter");
    if (presenter && SCITTEncodingMatches(presenter, @"model", @"@16@0:8")) {
        %init(SCITTVisitors);
        [installed addObject:@"-model (visitor log)"];
    } else {
        [skipped addObject:@"TTKProfileViewsPresenter -model"];
    }

    sciExtrasState = [NSString stringWithFormat:@"%@%@",
        installed.count ? [@"installed: " stringByAppendingString:
                              [installed componentsJoinedByString:@", "]]
                        : @"nothing installed",
        skipped.count ? [NSString stringWithFormat:@" — skipped: %@",
                            [skipped componentsJoinedByString:@"; "]]
                      : @""];

    SCILogV(@"[Extras] %@", sciExtrasState);
}
