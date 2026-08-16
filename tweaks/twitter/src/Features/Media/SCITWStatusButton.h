//
//  SCITWStatusButton.h
//  Albrhi for Twitter
//
//  Not a button any more -- the name is kept because two other files already import it by
//  it. What is left is the shared groundwork a button surface needs: the three status-view
//  classes, declared once so the promoted-tweet filter and the immersive button do not each
//  redeclare them, and the walk from a view up to whatever media its model can name.
//
//  The corner-of-the-picture button this file used to place was removed deliberately, along
//  with the inline-media and action-bar surfaces beside it -- all three, plus the immersive
//  one, were live at once, and a post with a video could show the save button four times
//  over: on the corner of the thumbnail, after the action row's own share button, in the
//  immersive rail, and pinned in the immersive card. The immersive surface is what the
//  owner actually asked for -- a button that stays inside the video while swiping -- and is
//  the only one kept. See SCITWImmersiveButton.x.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>
#import "SCITWMedia.h"

NS_ASSUME_NONNULL_BEGIN

/// Declared here, once, rather than in every file that hooks them.
///
/// A `%hook` on an undeclared class gets a forward declaration only, and `self` is then an
/// incomplete type -- the ternary error this project has already hit three times in three
/// shapes. The promoted-tweet filter hooks these same three classes, and a declaration
/// repeated there would be the exact duplicate-@interface failure `tools/check.py` rule 1
/// exists to catch -- caught here rather than at Theos.
///
/// Nothing is claimed about them beyond being views, which is all any caller needs.
@interface T1StandardStatusView : UIView
@end

@interface T1TweetDetailsFocalStatusView : UIView
@end

@interface T1ConversationFocalStatusView : UIView
@end

/// The first saveable media on the tweet a view is showing, or nil.
///
/// Walks `-viewModel` (or, failing that, treats the view as its own model if it answers
/// `-status` directly -- the immersive card does, with no `-viewModel` at all) down to
/// `-status.entities` and the first entity that resolves to something downloadable.
/// Shared because the immersive button and the promoted-tweet filter both need exactly
/// this walk and neither owns the classes it walks through.
SCITWMediaItem *_Nullable SCITWFirstSaveableInStatusView(UIView *view);

NS_ASSUME_NONNULL_END
