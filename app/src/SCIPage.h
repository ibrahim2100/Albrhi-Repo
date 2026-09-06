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

/// One choice on a sheet.
@interface SCIChoice : NSObject
+ (instancetype)titled:(NSString *)title does:(void (^)(void))does;
+ (instancetype)dangerous:(NSString *)title does:(void (^)(void))does;   // drawn in red
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) void (^does)(void);
@property (nonatomic, assign, readonly) BOOL dangerous;
@end

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

/// Puts text on the pasteboard and says so, with a tap of haptic behind it.
///
/// Half of what this app is for ends up in a WhatsApp message, and a code that has to be
/// transcribed by eye from a screen is a code that arrives wrong.
- (void)copyText:(NSString *)text;

/// Opens WhatsApp on that number with the message already written.
///
/// **The number is normalised to digits first.** People write one four ways — `0593010901`,
/// `+966 59 301 0901`, `٠٥٩٣٠١٠٩٠١` — and `wa.me` takes none of them but the last shape. A
/// leading zero becomes the Saudi country code, which is the one assumption here and is said out
/// loud rather than hidden. Answers NO when there is nothing dialable.
- (BOOL)whatsApp:(nullable NSString *)number saying:(NSString *)message;

/// Turns this page's list into a searchable one. Call from -viewDidLoad; read `query`.
- (void)searchableWith:(NSString *)placeholder;

/// The same, with a row of filters under the search field. `scope` is the chosen index.
///
/// The scope bar rather than a control of our own: it is where iOS puts a filter over a list, it
/// appears and disappears with the search field, and it costs no layout.
- (void)searchableWith:(NSString *)placeholder scopes:(NSArray<NSString *> *)scopes;

@property (nonatomic, copy, readonly, nullable) NSString *query;
@property (nonatomic, assign, readonly) NSInteger scope;

/// Chooses a filter without the user touching the bar, and moves the bar to match. A filter
/// applied invisibly is a list that has silently hidden rows.
- (void)selectScope:(NSInteger)scope;

/// Whether a row's own fields answer the current search.
///
/// **Digits are compared as digits.** Nobody writes a phone number the same way twice, so the
/// comparison folds Arabic-Indic numerals, throws away everything that is not a digit, and
/// matches on the last nine — which is what makes `+966 59 301 0901` and `0593010901` one number.
/// Text is matched as an ordinary substring beside it.
- (BOOL)matches:(NSArray<NSString *> *)fields;

/// Called when the search text or the chosen filter changes, before the table is asked to draw
/// again. A page that keeps its unfiltered list refilters here.
- (void)queryChanged;

/// What a swipe from the row's trailing edge offers. Empty by default.
///
/// The same `SCIChoice` a sheet is built from, so a page describes an action once and it can be
/// reached both ways — two lists of one truth is the shape this project keeps paying for.
- (NSArray<SCIChoice *> *)swipeActionsAt:(NSInteger)row;

/// Shows another tab, and hands it back so the caller can aim it before it appears.
- (nullable __kindof SCIPage *)showTab:(NSInteger)index;

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
