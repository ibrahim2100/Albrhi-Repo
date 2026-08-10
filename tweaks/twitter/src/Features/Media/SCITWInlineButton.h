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
