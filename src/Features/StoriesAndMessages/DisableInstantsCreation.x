#import "../../Utils.h"

#define QUICKSNAPENABLED() do { _Bool __o = %orig; return [SCIUtils getBoolPref:@"disable_instants_creation"] ? false : __o; } while (0)

// Demangled name: IGQuickSnapExperimentation.IGQuickSnapExperimentationHelper
%hook _TtC26IGQuickSnapExperimentation32IGQuickSnapExperimentationHelper
+ (_Bool)isQuicksnapEnabled:(id)enabled {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapEnabledInFeed:(id)feed {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapEnabledInInbox:(id)inbox {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapEnabledInStories:(id)stories {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapEnabledInNotesTray:(id)tray {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPeek:(id)peek {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPog:(id)pog {
    QUICKSNAPENABLED();
}
+ (_Bool)isQuicksnapNotesTrayEmptyPogEnabled:(id)enabled {
    QUICKSNAPENABLED();
}
// + (_Bool)isStoriesSpringEnabled:(id)enabled {
//     return true;
// }
// + (_Bool)shouldEnableScreenshotBlocking:(id)blocking {
//     return false;
// }
// + (_Bool)areFiltersEnabled:(id)enabled {
//     return true;
// }
// + (_Bool)isBottomsheetCustomAudienceEnabled:(id)enabled {
//     return true;
// }
// + (_Bool)isVideoCaptureEnabled:(id)enabled {
//     return true;
// }
%end

// %hook IGDirectNotesTrayRowCell
// - (_Bool)isQuicksnapPeekVisible {
//     return true;
// }
// %end

// %hook IGDirectNotesTrayRowSectionController
// - (_Bool)isQuicksnapPeekVisible {
//     return true;
// }
// %end