//
//  SCIResponder.h
//  Albrhi — shared
//
//  "Which view controller do I present this from?", answered once.
//
//  **Twelve copies of this walk existed across four tweaks, and they were not the same walk.**
//  `SCIControllerAbove` in YouTube's download button, `SCIOwningController` in its player
//  overlay, and further copies in TikTok, Instagram and YouTube Music — some starting at the
//  view itself and some at its `nextResponder`, some descending into `presentedViewController`
//  and some not. So "there was nothing to present from" was four different bugs with four
//  different fixes, and fixing one taught the others nothing.
//
//  The walk itself is the right technique and none of the copies were wrong about that: the
//  responder chain is UIKit's, so it cannot be renamed out from under a hook the way every
//  app class this project touches has been. What was wrong is having four of it.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// The view controller a view belongs to, descended to whatever it is currently presenting.
///
/// Starts at the view itself, because a view *can* be its controller's own `view` and starting
/// at `nextResponder` would then skip the answer. Ends at the topmost presented controller,
/// because presenting from underneath one is the single most common way a sheet silently never
/// appears — UIKit refuses it and says so only in the log.
///
/// nil when the view is in no hierarchy that leads to a controller, which is a real state
/// during layout and is why every caller has to check.
UIViewController *_Nullable SCIControllerForView(UIView *_Nullable view);

/// The same, from any responder — a gesture recogniser's `view`, a control's target, a cell.
UIViewController *_Nullable SCIControllerForResponder(UIResponder *_Nullable responder);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
