//
//  SCITWReport.h
//  Albrhi for Twitter
//
//  What actually happened on this phone, as plain text.
//
//  The settings screen shows the same facts more prettily, and this exists anyway: a
//  screenshot of a table cannot be searched, quoted, or diffed against the same table a
//  week later, and the whole point of this release is that what it saw on real devices
//  decides what the next one does.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The report as text: version, what attached, the panel switch, and every switch seen
/// with its counts and answers.
NSString *SCITWReportText(void);

/// Writes it into the app's own Documents folder, which is reachable from the Files app
/// without a jailbreak file manager. Returns the file name on success and nil on failure
/// -- the caller says which to the user, because "saved" and "saved somewhere you cannot
/// find" are the same sentence otherwise.
NSString *_Nullable SCITWWriteReport(void);

NS_ASSUME_NONNULL_END
