#import "SCIYTSubpageController.h"

@interface SCIYTSubpageController ()
@property (nonatomic, strong) SCIYTPage *page;
@end

@implementation SCIYTSubpageController

- (instancetype)initWithPage:(SCIYTPage *)page {
    self = [super init];
    if (self) {
        _page = page;
        self.title = page.title;
    }
    return self;
}

/// Nothing here decides what a page contains -- the page does, in its own file, exactly as
/// it did when every page was a heading on one long scroll. The only thing that changed is
/// that its sections are the whole of a screen instead of part of one.
- (void)buildSections {
    self.sections = [self.page sectionsFor:self];
}

@end
