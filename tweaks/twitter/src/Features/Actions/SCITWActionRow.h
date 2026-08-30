//
//  SCITWActionRow.h
//  Albrhi for X
//
//  Buttons under a post, and one of them turned into a picture.
//
//  **BHTwitter removes a button by answering the class list X builds the row from, and that
//  method is not in X 12.20.** `+_t1_inlineActionViewClassesForViewModel:options:displayType:
//  account:` is gone, so the row cannot be composed differently — the buttons are already
//  built by the time this tweak can see them, and the only honest thing left is to hide the
//  one instance. `TTAStatusInlineActionsView` lays its buttons out by hand rather than in a
//  stack view, so a hidden button may leave the space it occupied; the report says how many
//  were hidden so a gap is attributable rather than mysterious.
//
//  The bind point is `-setViewModel:options:displayType:displayTextOptions:account:`, which
//  this tweak already hooks for the download button — it fires on reuse as well as on first
//  use, which `-didMoveToWindow` does not, and that distinction cost four releases once.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWActionRowReport(void);
void SCITWInstallActionRow(void);
