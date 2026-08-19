//
//  SCITTReport.h
//  Albrhi for TikTok
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

///
/// The diagnostics, on a screen of their own.
///
/// Every row here is engineering: which hook attached, which accessor chain won, what the gears
/// measured in bytes, what a class's real method list holds. It used to be a third section of the
/// settings screen, which made two thirds of that screen unreadable to the person it was for --
/// and made the switches, the only part anybody came to change, look like a preamble to a log.
///
/// It is not hidden, because this project's own loop depends on it: the report is how a device
/// answers a question no class dump can. It is one row away instead of underneath.
///
@interface SCITTReport : UITableViewController

/// Everything on this screen as plain text -- what the Copy button puts on the pasteboard.
///
/// Exposed rather than private because the settings screen offers the same copy from its own row:
/// somebody sending a report should not have to find the right screen first. **One function, two
/// callers** -- the alternative is the divergence this file's own comment warns about, where the
/// copied text and the screen it claims to mirror are built from two lists.
+ (NSString *)reportText;

/// The same, plus the class dumps the ordinary report leaves out.
///
/// Two texts rather than one long one: an ordinary report is read by a person and should fit in a
/// message, while a class's whole method list is only ever wanted when a class list is the actual
/// question. Both walk the same list of rows, so neither can miss a row the other has.
+ (NSString *)fullReportText;

@end
