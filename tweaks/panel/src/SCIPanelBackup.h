//
//  SCIPanelBackup.h
//  Albrhi Panel
//
//  Albrhi's settings, out of the phone and back into it.
//
//  **What this can and cannot carry, said here rather than discovered later.** Everything the
//  panel owns lives in one domain: the master switch and one key per patched app. Each tweak's
//  own sub-options live inside that app's container, where the Settings app is not permitted to
//  read -- so a backup that claimed to hold "all your Albrhi settings" would be quietly wrong
//  about most of them. It holds the panel's domain, the footer says exactly that, and nobody
//  restores a file expecting something it never contained.
//
//  The file goes out through the share sheet on purpose. A rootless or roothide prefix is
//  removed with the bootstrap, so a backup written beside the preferences it copies would be
//  destroyed by precisely the event it exists for.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Writes the panel's whole domain to a temporary file and returns it, or nil when the domain
/// could not be read. The name carries the date, so several backups never collide.
NSURL *_Nullable SCIPanelBackupWrite(void);

/// Applies a backup file. Returns the number of keys restored, or -1 when the file is not a
/// backup this panel wrote -- a wrong file is refused rather than half-applied.
NSInteger SCIPanelBackupRestore(NSURL *url);

NS_ASSUME_NONNULL_END
