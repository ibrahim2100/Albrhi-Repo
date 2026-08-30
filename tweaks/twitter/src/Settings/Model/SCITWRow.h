//
//  SCITWRow.h
//  Albrhi for X
//
//  What a settings row is, described rather than drawn.
//
//  **The screen this replaces addressed its rows by index.** Five section constants and
//  seven row constants, a `numberOfRowsInSection:` returning a hand-written count, and a
//  `switch` per section deciding what each index meant — three lists of one truth, which is
//  the shape that crashed the YouTube Music settings screen when a fourth was added and one
//  of them was not updated. A row here carries its own title, its own preference key and its
//  own action, so a section's length is `rows.count` and there is nothing to keep in step.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCITWRowKind) {
    /// A preference, on or off.
    SCITWRowKindSwitch,
    /// Taps to do something — open a screen, ask a question, copy a report.
    SCITWRowKindAction,
    /// Reads back a value and cannot be tapped. The diagnostics live in these.
    SCITWRowKindInfo,
};

@interface SCITWRow : NSObject

@property (nonatomic, assign) SCITWRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *note;

/// An SF Symbol and the colour of the rounded badge it sits in — the same shape Settings
/// itself uses, so a long list of switches is scannable by colour rather than only by text.
@property (nonatomic, copy, nullable) NSString *symbol;
@property (nonatomic, strong, nullable) UIColor *tint;

/// Switch rows only.
@property (nonatomic, copy, nullable) NSString *prefKey;

/// Action rows only.
@property (nonatomic, copy, nullable) void (^action)(void);

/// Info rows only. Read at draw time, so a count is current rather than whatever it was
/// when the screen was built.
@property (nonatomic, copy, nullable) NSString * (^value)(void);

/// Marks a row as one that removes something, changes what X is told about the device, or
/// turns on something X ships switched off. Drawn in a warning colour rather than explained
/// only in a note somebody may not read.
@property (nonatomic, assign) BOOL cautious;

/// Drawn as the heading of the screen rather than as one row among many: a larger badge, a
/// bold title, and a tinted panel behind it.
///
/// **For a row the rest of the screen depends on**, not for a favourite one. The switch
/// layer is the only user today, and it earns it: turning it off takes the whole feature
/// list away, so a switch that governs what is below it has no business being below it.
@property (nonatomic, assign) BOOL prominent;

/// Run after a switch row is flipped, for a preference that something else has to be told
/// about. The feature layer is the only user today: its map is recomputed from scratch on
/// every change, which is the whole reason turning a feature off cannot get anything wrong.
@property (nonatomic, copy, nullable) void (^onChange)(BOOL on);

+ (instancetype)switchRow:(NSString *)title
                     note:(nullable NSString *)note
                   symbol:(nullable NSString *)symbol
                     tint:(nullable UIColor *)tint
                  prefKey:(NSString *)prefKey;

+ (instancetype)actionRow:(NSString *)title
                     note:(nullable NSString *)note
                   symbol:(nullable NSString *)symbol
                     tint:(nullable UIColor *)tint
                   action:(void (^)(void))action;

+ (instancetype)infoRow:(NSString *)title value:(NSString * (^)(void))value;

@end


@interface SCITWSection : NSObject
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *footer;
@property (nonatomic, copy) NSArray<SCITWRow *> *rows;

+ (instancetype)titled:(nullable NSString *)title
                footer:(nullable NSString *)footer
                  rows:(NSArray<SCITWRow *> *)rows;
@end

NS_ASSUME_NONNULL_END
