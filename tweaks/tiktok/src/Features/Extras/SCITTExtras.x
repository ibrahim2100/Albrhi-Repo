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
#import "../../SCILog.h"

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
    if (!SCIPrefEnabled(SCIPrefKeepRecalled)) return %orig;

    // The message is still here: TikTok received it, then received an instruction to hide it, and
    // hiding is done by the client. Nothing is fetched back from a server -- what is refused is the
    // instruction to stop showing what already arrived.
    return NO;
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
    return [NSString stringWithFormat:@"%@; visitors remembered: %lu (%lu seen this launch)",
            sciExtrasState ?: @"not installed",
            (unsigned long)SCITTVisitorLog().count, (unsigned long)sciVisitorsSeen];
}

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
