#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Compat/SCIResolve.h"

// Disable story data source
%group SCIgIGMainStoryTrayDataSource

%hook IGMainStoryTrayDataSource
- (id)initWithUserSession:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_stories_tray"]) {
        SCILogV(@"[SCInsta] Hiding story tray");

        return nil;
    }
    
    return %orig;
}
%end

%end

%ctor {
    Class mainStoryTrayDataSource = SCIResolveClass(@"IGMainStoryTrayDataSource");
    if (mainStoryTrayDataSource) %init(SCIgIGMainStoryTrayDataSource, IGMainStoryTrayDataSource = mainStoryTrayDataSource);
}
