#import "SCITWSwitches.h"
#import "Prefs.h"
#import "SCILog.h"

///
/// The hooks themselves. Three classes, one question.
///
/// Each provider gets its own `%group`, initialised only when the class is really there.
/// A `%hook` on a class this build of X does not have is not an error and not a crash --
/// it is silence, and silence is the failure mode this project has spent the most time
/// paying for. With a group per provider the diagnostics page can say "two of three
/// attached", which is a sentence somebody can act on.
///
/// `-unsafePeekBoolForKey:` is hooked beside `-boolForKey:` because it is the same
/// question asked without waiting for the cache, and code that takes that route would
/// otherwise see X's answer where its neighbour sees the user's -- one screen obeying the
/// override and the one beside it not, which reads as the tweak being unreliable rather
/// than as a route that was missed.
///

%group Switches

%hook TFSFeatureSwitches

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSFeatureSwitches"
                         answer:&answer];
    return answer;
}

- (BOOL)unsafePeekBoolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSFeatureSwitches"
                         answer:&answer];
    return answer;
}

%end

%end


%group CachingProvider

%hook TFSCachingFeatureSwitchProvider

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TFSCachingFeatureSwitchProvider"
                         answer:&answer];
    return answer;
}

%end

%end


%group TPSwitches

%hook TPSTwitterFeatureSwitches

- (BOOL)boolForKey:(NSString *)key {
    BOOL answer = %orig;
    [SCITWSwitches interceptKey:key
                      appAnswer:answer
                       provider:@"TPSTwitterFeatureSwitches"
                         answer:&answer];
    return answer;
}

%end

%end


/// Attaches what is there and records what was not.
///
/// Called from the constructor rather than being a `%ctor` of its own, so the order is
/// visible in one file: the panel switch is consulted first, and nothing here runs when
/// this tweak has been turned off for X.
///
/// Written out three times rather than driven from a table, because `%init` is a macro
/// that expands to registration calls for one named group -- it cannot be reached through
/// a function pointer, and a loop over the three would have to be a loop over something
/// else entirely. Three near-identical paragraphs that compile beat one clever one that
/// does not.
///
void SCITWInstallSwitchHooks(void) {
    // The classes live in T1Twitter.framework and the two SPM migration frameworks, not
    // in the main binary -- so anything that looks for them by scanning the executable
    // finds nothing and concludes, wrongly, that this build of X has no switch layer.
    // Asking the runtime by name asks every image that is loaded, which is the point.
    if (NSClassFromString(@"TFSFeatureSwitches")) {
        %init(Switches);
        [SCITWSwitches noteProvider:@"TFSFeatureSwitches"];
    } else {
        SCILogV(@"TFSFeatureSwitches is not in this build");
    }

    if (NSClassFromString(@"TFSCachingFeatureSwitchProvider")) {
        %init(CachingProvider);
        [SCITWSwitches noteProvider:@"TFSCachingFeatureSwitchProvider"];
    } else {
        SCILogV(@"TFSCachingFeatureSwitchProvider is not in this build");
    }

    if (NSClassFromString(@"TPSTwitterFeatureSwitches")) {
        %init(TPSwitches);
        [SCITWSwitches noteProvider:@"TPSTwitterFeatureSwitches"];
    } else {
        SCILogV(@"TPSTwitterFeatureSwitches is not in this build");
    }
}
