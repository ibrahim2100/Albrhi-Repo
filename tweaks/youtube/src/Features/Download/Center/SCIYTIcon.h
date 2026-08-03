//
//  SCIYTIcon.h
//  Albrhi for YouTube
//
//  The Downloads mark, drawn rather than borrowed.
//
//  The tab used an SF Symbol, which was fine and was also visibly not one of YouTube's:
//  Apple's glyphs carry Apple's weight and corner treatment, and next to five tabs drawn
//  to a different rule the odd one out is the one you notice. This is drawn to sit with
//  them -- a plain stroke of even weight, a flat tray, no fill and no circle -- and the
//  label goes underneath it, which is YouTube's own doing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

@interface SCIYTIcon : NSObject

/// The mark, as a template image so whoever draws it picks the colour.
///
/// Cached per size and weight: the tab asks for it every time the bar is rebuilt, which is
/// on every rotation and page style change, and redrawing a bezier path each time to get
/// the same twenty pixels back is work nobody asked for.
+ (UIImage *)downloadMarkOfSize:(CGFloat)size filled:(BOOL)filled;

@end
