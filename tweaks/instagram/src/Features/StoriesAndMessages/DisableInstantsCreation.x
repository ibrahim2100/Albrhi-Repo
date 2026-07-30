#import "../../Utils.h"

// Helper: returns false when the feature is enabled, otherwise the original value.
static inline _Bool _quicksnapValue(_Bool orig) {
    return [SCIUtils getBoolPref:@"disable_instants_creation"] ? false : orig;
}

// Demangled name: IGQuickSnapExperimentation.IGQuickSnapExperimentationHelper
%hook _TtC26IGQuickSnapExperimentation32IGQuickSnapExperimentationHelper
+ (_Bool)isQuicksnapEnabled:(id)enabled {
    _Bool orig = %orig(enabled);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapEnabledInFeed:(id)feed {
    _Bool orig = %orig(feed);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapEnabledInInbox:(id)inbox {
    _Bool orig = %orig(inbox);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapEnabledInStories:(id)stories {
    _Bool orig = %orig(stories);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapEnabledInNotesTray:(id)tray {
    _Bool orig = %orig(tray);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPeek:(id)peek {
    _Bool orig = %orig(peek);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPog:(id)pog {
    _Bool orig = %orig(pog);
    return _quicksnapValue(orig);
}
+ (_Bool)isQuicksnapNotesTrayEmptyPogEnabled:(id)enabled {
    _Bool orig = %orig(enabled);
    return _quicksnapValue(orig);
}
%end
