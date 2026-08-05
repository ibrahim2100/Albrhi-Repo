//
//  SCIYTSectionsController.h
//  Albrhi for YouTube
//
//  A table that draws an array of SCISection, and nothing else.
//
//  Everything about how a row looks -- the dark card, the switch wired to its own key, the
//  subtitle, the symbol -- lived in the settings screen. Splitting the settings into a list
//  of pages meant a second screen needing every one of those, and the choice was to copy a
//  hundred lines or to name the part both screens are.
//
//  So this is that part. The first screen is a list of page names and each page is a list of
//  rows, and those are the same table with different sections in it. Neither subclass knows
//  how a switch is drawn; both only answer what to put in it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "../Settings/SCIYTSettingsRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIYTSectionsController : UITableViewController <SCIYTSettingsHost>

/// What the table is showing. Replaced by -buildSections, never assigned from outside.
@property (nonatomic, strong) NSArray<SCISection *> *sections;

/// Decides what this screen holds. **Subclasses must override**; the base builds nothing,
/// which is the right answer for a screen nobody has told what to show.
- (void)buildSections;

@end

NS_ASSUME_NONNULL_END
