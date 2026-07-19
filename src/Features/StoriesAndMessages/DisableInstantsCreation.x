#import "../../Utils.h"

// Helper: returns false when the feature is enabled, otherwise the original value.
static inline _Bool _quicksnapValue(_Bool orig) {
    return [SCIUtils getBoolPref:@"disable_instants_creation"] ? false : orig;
}

// Demangled name: IGQuickSnapExperimentation.IGQuickSnapExperimentationHelper
%hook _TtC26IGQuickSnapExperimentation32IGQuickSnapExperimentationHelper
+ (_Bool)isQuicksnapEnabled:(id)enabled {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapEnabledInFeed:(id)feed {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapEnabledInInbox:(id)inbox {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapEnabledInStories:(id)stories {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapEnabledInNotesTray:(id)tray {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPeek:(id)peek {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPog:(id)pog {
    return _quicksnapValue(%orig);
}
+ (_Bool)isQuicksnapNotesTrayEmptyPogEnabled:(id)enabled {
    return _quicksnapValue(%orig);
}
%end
