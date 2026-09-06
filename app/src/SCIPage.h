//
//  SCIPage.h
//  Albrhi Licences
//
//  **What every page here has in common, written once.**
//
//  Six screens that each fetch, show rows, fail, and refresh. Writing that six times is how the
//  fourth one ends up without an empty state and the fifth without an error message — the same
//  reason this project has one download path and one responder walk rather than four of each.
//
//  A page says what it is loading, what it found, and what went wrong, and it never leaves a
//  spinner behind: "nothing yet" and "could not ask" look identical on a blank screen and need
//  different things done about them.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIPage : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong, readonly) UITableView *table;

/// Subclasses override these three.
- (void)fetch;                      ///< ask the server, then call -loaded: or -failed:
- (NSInteger)rowCount;
- (void)configure:(UITableViewCell *)cell at:(NSInteger)row;

/// Optional.
- (nullable NSString *)emptyMessage; ///< shown when rowCount is 0 and nothing failed
- (void)tapped:(NSInteger)row;

/// Asks again. Safe to call from anywhere: a fetch already in flight is left alone rather than
/// stacked, which is what stops a tap-happy moment from queuing six identical requests.
- (void)reload;

/// Called by subclasses when a fetch finishes.
- (void)loaded;
- (void)failed:(NSString *)why;

/// A row with a title, a value and an optional subtitle, in the house style.
- (UITableViewCell *)cellTitled:(NSString *)title
                          value:(nullable NSString *)value
                           note:(nullable NSString *)note;

/// One text field, one answer. Used for a name, a number of days, a code.
- (void)askTitled:(NSString *)title
          message:(nullable NSString *)message
            value:(nullable NSString *)value
         keyboard:(UIKeyboardType)keyboard
             then:(void (^)(NSString *answer))then;

/// Puts a number on this page's tab, or takes it off with nil.
///
/// **Not `self.tabBarItem`.** Every page here is inside a navigation controller, and it is the
/// *navigation controller* the tab bar holds — so a badge written onto the page's own item is
/// written onto an item nothing is displaying, and the count simply never appears.
- (void)badge:(nullable NSString *)value;

/// Says something briefly, without a button to dismiss.
- (void)say:(NSString *)message;

/// A date, formatted the one way this app formats dates.
+ (NSString *)dateFrom:(NSNumber *)seconds;

@end

/// Wraps one run of text so bidi cannot rearrange it against what sits beside it.
///
/// **A store id and a date on one Arabic line merge into nonsense without this.** «متجر na9 ·
/// 15/09/2026» renders as «متجر 15 · 2026/09/na9»: the Latin id and the date's digits are one
/// left-to-right run as far as the algorithm is concerned, and the separator between them is
/// neutral. The isolate characters (FSI … PDI) say where one run ends, which is exactly the fact
/// the algorithm is missing. This is the same family as the post-to-image bug in the X tweak —
/// a mistake only ever seen on an Arabic phone.
NSString *SCIRun(NSString *_Nullable text);

/// One choice on a sheet.
@interface SCIChoice : NSObject
+ (instancetype)titled:(NSString *)title does:(void (^)(void))does;
+ (instancetype)dangerous:(NSString *)title does:(void (^)(void))does;   // drawn in red
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) void (^does)(void);
@property (nonatomic, assign, readonly) BOOL dangerous;
@end

@interface SCIPage (Sheet)

/// An action sheet, in the order given. The last one is Cancel and is added here so no page can
/// forget it.
///
/// **An array, because a dictionary has no order.** The first version took one, and the approve
/// sheet came out «six months · decline · lifetime · month · year» — terms out of sequence with
/// the destructive one in the middle of them, which is where a mis-tap costs somebody a licence.
- (void)sheetTitled:(nullable NSString *)title
            message:(nullable NSString *)message
            choices:(NSArray<SCIChoice *> *)choices;

@end


NS_ASSUME_NONNULL_END
