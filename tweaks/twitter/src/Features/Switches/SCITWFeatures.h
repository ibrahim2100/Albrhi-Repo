//
//  SCITWFeatures.h
//  Albrhi for Twitter
//
//  Named features, built out of the keys a real phone reported.
//
//  0.1.0 shipped the recorder and nothing else, because a table of key names written from
//  reading X's binary is a table of guesses. This file is what the recorder was for: every
//  key below was observed being asked on a device running X 12.14, with the answer X gave
//  and the number of times it was asked, so nothing here is speculation about whether the
//  key exists or is consulted.
//
//  **What is still inference is what each key does.** A name is evidence, not proof: X
//  chose these names for its own engineers and nobody outside has the code that reads them.
//  So the screen says so, each feature names the exact keys it moves, and every one of them
//  can be undone -- individually from the switch list, or all at once.
//
//  ## Two layers, and why
//
//  A named feature and a hand-set key are different kinds of decision, and the first
//  version of this collapsed them into one dictionary. That works until a feature is turned
//  off: its keys have to be removed, but only the ones no other enabled feature also wants,
//  and only if the user did not set one of them by hand in the meantime. That bookkeeping
//  is where the bugs live.
//
//  So they are kept apart. Features contribute one map, recomputed from scratch whenever
//  any of them changes; hand-set keys are their own map and always win. Turning a feature
//  off is a recompute, not a removal, and there is nothing to get wrong.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// One thing a person would ask for, and the switches it is made of.
@interface SCITWFeature : NSObject

/// Stable, and stored. Renaming one silently turns it off on every device that had it on,
/// so these are never changed once released.
@property (nonatomic, copy) NSString *identifier;

/// Localization keys, not text. `title` names the feature and `note` says plainly what it
/// does and what it costs -- a switch that removes a warning or changes how X reports
/// itself has to say so before it is flipped, not after.
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *noteKey;

/// The switches, and what this feature wants each of them to answer.
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *keys;

/// Whether it deserves a warning colour: it removes a disclosure, changes what X is told
/// about the device, or turns on something X shipped switched off.
@property (nonatomic, assign) BOOL cautious;

/// An SF Symbol name and a colour, for the badge the settings screen draws beside each
/// feature -- the same rounded-square-icon shape Settings.app itself uses. Kept here rather
/// than hard-coded per row in the screen, so a feature and the way it is drawn cannot drift
/// apart when the table above gains a row and someone forgets the screen fifty lines below.
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong) UIColor *iconColor;

@end


@interface SCITWFeatures : NSObject

/// The whole list, in the order the settings screen shows it.
+ (NSArray<SCITWFeature *> *)all;

+ (BOOL)isOn:(SCITWFeature *)feature;
+ (void)setOn:(BOOL)on feature:(SCITWFeature *)feature;

/// Recomputes the feature layer from every switched-on feature and hands it to
/// SCITWSwitches. Called at launch and after any change.
+ (void)apply;

/// Which feature, if any, is the reason a key is being answered for X. Nil when no
/// enabled feature names it. For the settings screen, so a row can say where its value
/// came from rather than leaving someone to work it out.
+ (nullable SCITWFeature *)featureOwningKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
