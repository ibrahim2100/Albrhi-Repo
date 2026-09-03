//
//  SCITitleMatch.h
//  Albrhi for Instagram
//
//  Matching a row by the English words printed on it — and admitting that is what we are doing.
//
//  **Fourteen features here compare a view model's title against an English literal**
//  (`@"Ask Meta AI"`, `@"Suggested for you"`, `@"Meta AI"`), inherited from SCInsta. Instagram
//  translates those titles, so on an Arabic phone — which is the phone this project is
//  developed on — none of them ever matches. The switch says the row is hidden and the row is
//  right there.
//
//  CLAUDE.md already names this mistake, for the Watch tweak: *matching "Download and Install"
//  is matching a localised string, right in English and wrong everywhere else.* There it could
//  be replaced, because the page had structure to match on instead. Here it cannot yet: these
//  view models expose no identifier this project has confirmed, and inventing one would be the
//  exact guess this repository has paid for on four different apps.
//
//  **So the honest thing is not to pretend, and not to delete a feature that works for someone.**
//  Every one of those comparisons goes through here, which does three things:
//
//    1. matches, exactly as before, so an English interface keeps working;
//    2. counts what it saw and what it matched, per surface;
//    3. puts that in the diagnostics report, so `12 seen, 0 matched` says plainly that this
//       surface depends on the interface language rather than looking like a broken hook.
//
//  A zero here is the evidence needed to replace the comparison properly: it names the surface,
//  and the next step is reading that view model's own accessors on a device.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Does `title` equal any of `englishTitles`?
///
/// `surface` names the place this is being asked from — it is the label the diagnostics report
/// groups the counts under, so it should read as somewhere in the app ("story tray",
/// "search results"), not as a class name.
BOOL SCIMatchesEnglishTitle(NSString *_Nullable title,
                            NSArray<NSString *> *englishTitles,
                            NSString *surface);

/// One line per surface: seen, matched, and whether the phone's interface is English at all.
/// Empty until a surface has been visited.
NSArray<NSString *> *SCIEnglishTitleReport(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
