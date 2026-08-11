//
//  SCITWInlineButton.h
//  Albrhi for Twitter
//
//  A download button on the video itself.
//
//  The other surface -- the list under the two-finger hold -- stays, and this is added
//  beside it rather than instead of it. The list never breaks when X renames a view,
//  because it hooks the model; this button is on a view and therefore can, so the two
//  cover each other: if a future X moves the chrome this sits in, the list is still there,
//  and the log says which of the two attached.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

/// Hooks X's inline media view to add the button, if this build has that class. Safe to
/// call when it does not.
void SCITWInstallInlineButton(void);

/// What the button did, for the diagnostics page.
///
/// "It did not appear" has four causes that look the same from outside a phone, and
/// nothing here recorded which one it was -- so the first report about it could not be
/// acted on. This says: whether the class exists, whether the hook attached, how many
/// models arrived, how many held media, and how many buttons were placed.
NSString *SCITWInlineButtonReport(void);
