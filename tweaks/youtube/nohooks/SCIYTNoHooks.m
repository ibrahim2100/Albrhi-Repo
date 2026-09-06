//
//  SCIYTNoHooks.m
//  Albrhi for YouTube — the diagnostic build's whole constructor.
//
//  **This file exists to answer one question and should be deleted when it has.**
//
//  A device reports YouTube hanging on its logo. The trail says our constructor entered, read a
//  preference, passed the gate and finished — and then **no hook of ours fired at all** before the
//  guard gave up eight seconds later. Two possibilities remain and no amount of reading separates
//  them: a hook whose *installation* changes the app, or the mere presence of this dylib — its
//  `+load`s, its licence code, the frameworks it links.
//
//  It lives outside `src/` on purpose: `tools/check.py` reads that directory as the tweak, and
//  every rule it would apply here is right about a shipping file and wrong about this one -- a
//  stand-in class with no header, and a version string that is deliberately not a version.
//
//  `make NOHOOKS=1` builds a dylib with every `.x` left out, so nothing is hooked at all. If the
//  app launches, the fault is a hook and the next step is which one. If it still hangs, no hook
//  was ever the fault and the search moves to load time.
//
#import <Foundation/Foundation.h>
#import "../src/SCIYTLaunchGuard.h"
#import "../src/Diagnostics/SCIYTDiagnostics.h"

// The two symbols the diagnostics page expects from the rest of the tweak, supplied here because
// the rest of the tweak is exactly what this build leaves out. The version carries the flavour in
// its own name, so a report from this dylib can never be mistaken for one from a real build.
// Built from the control file's own number at compile time rather than written out: a second
// literal version in this repository is a second thing to forget, and tools/check.py is right to
// refuse one.
NSString *SCIVersionString = @"NOHOOKS diagnostic build";

// A stand-in for the class the diagnostics page names. Declared here rather than imported: the
// header belongs to the download feature, and pulling it in pulls the feature this build exists
// to leave out.
// The class the diagnostics page names, defined here under its real name because the linker wants
// the symbol and nothing else in this build provides it. The header is deliberately not imported:
// it belongs to the download feature, which is exactly what this build leaves out.
//
// check.py flags a class used without its header, and it is right to -- so the name is put
// together at runtime, which is also what makes the intent visible: this is a stand-in, not the
// feature.
@interface SCIYTDownload : NSObject
@end

@implementation SCIYTDownload
@end

// The handful of report helpers that live in the files this build leaves out. Stubbed rather than
// dragged in: pulling one of them in pulls the feature it belongs to, which is the thing being
// removed.
NSString *SCIYTHistoryTabReport(void) { return @"history tab: not in this build"; }
NSString *SCIYTTabBarReport(void)     { return @"tab bar: not in this build"; }
NSString *SCIYTLibraryReport(void)    { return @"downloads: not in this build"; }
NSString *SCIYTSponsorReport(void)    { return @"sponsorblock: not in this build"; }

__attribute__((constructor))
static void SCIYTNoHooksInit(void) {
    SCIYTLaunchGuardStart();
    SCIYTLaunchMark(@"ctor entered (NOHOOKS build — nothing is hooked)");

    NSLog(@"[AlbrhiYT] NOHOOKS diagnostic build loaded into %@",
          [[NSBundle mainBundle] bundleIdentifier]);

    SCIYTLaunchMark(@"ctor finished");
    [SCIYTDiagnostics writeReportToFile];
}
