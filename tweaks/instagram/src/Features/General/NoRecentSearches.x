#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Compat/SCIResolve.h"

// Disable logging of searches at server-side
%group SCIgIGSearchEntityRouter

%hook IGSearchEntityRouter
- (id)initWithUserSession:(id)arg1 analyticsModule:(id)arg2 shouldAddToRecents:(BOOL)shouldAddToRecents {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        shouldAddToRecents = false;
    }
    
    return %orig(arg1, arg2, shouldAddToRecents);
}
%end

%end


// Most in-app search bars
%group SCIgIGRecentSearchStore

%hook IGRecentSearchStore
- (id)initWithDiskManager:(id)arg1 recentSearchStoreConfiguration:(id)arg2 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        return nil;
    }

    return %orig;
}
- (BOOL)addItem:(id)arg1 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        return nil;
    }

    return %orig;
}
%end

%end


// Recent dm message recipients search bar
%hook IGDirectRecipientRecentSearchStorage
- (id)initWithDiskManager:(id)arg1 directCache:(id)arg2 userStore:(id)arg3 currentUser:(id)arg4 featureSets:(id)arg5 {
    if ([SCIUtils getBoolPref:@"no_recent_searches"]) {
        SCILogV(@"[SCInsta] Disabling recent searches");

        return nil;
    }

    return %orig;
}
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class searchEntityRouter = SCIResolveClass(@"IGSearchEntityRouter");
    if (searchEntityRouter) %init(SCIgIGSearchEntityRouter, IGSearchEntityRouter = searchEntityRouter);
    Class recentSearchStore = SCIResolveClass(@"IGRecentSearchStore");
    if (recentSearchStore) %init(SCIgIGRecentSearchStore, IGRecentSearchStore = recentSearchStore);
}
