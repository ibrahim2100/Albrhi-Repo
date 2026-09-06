//
//  SCINotify.h
//  Albrhi Licences
//
//  **A request that arrives while the app is closed is a request nobody sees.**
//
//  The whole point of the panel arriving on a phone is that somebody asking for a licence gets an
//  answer in minutes rather than whenever the laptop is next opened. That needs the app to look
//  without being opened, which iOS allows in exactly one way for an app like this: a background
//  refresh task that the system schedules when it feels like it, and a local notification when
//  the answer is worth waking somebody for.
//
//  Two honest limits, said here rather than discovered:
//
//    * **iOS decides when.** `BGAppRefreshTask` is a request, not a timer -- a phone that is warm,
//      charged and on wifi gets minutes, one that is not may get hours. This is a nudge, never a
//      guarantee, and the app's own pull-to-refresh remains the way to *know*.
//    * **And it only counts.** The task compares how many requests are waiting against the number
//      it last saw; it does not fetch details, and it never approves anything. A background task
//      that could grant a licence is a background task worth attacking.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted whenever the waiting count is known, with the count boxed as the object.
///
/// The tab badge cannot wait for the Requests page to be opened: a page inside a tab bar is not
/// built until somebody taps it, so a badge written from its own fetch is a badge that appears
/// only after it is no longer needed.
extern NSString *const SCIRequestsWaitingNotification;

@interface SCINotify : NSObject

/// Warns about licences ending within the week, once a day each. Called by the refresh; exposed
/// so the state screen can say what it would do.
+ (void)noticeExpiring:(nullable id)licences;

/// Leaves the home screen widget's three numbers in the shared container. Nothing secret goes in.
+ (void)writeCounts:(NSDictionary *)state;

/// Registers the background task. Called once, from the app delegate, before the launch finishes:
/// the system requires the identifier to be known by then and refuses it afterwards.
+ (void)registerTask;

/// Whether notifications are on for this install.
+ (BOOL)isOn;

/// Turns them on (asking iOS for permission the first time) or off. `why` is a sentence to show
/// when something refused; nil when nothing did.
+ (void)toggle:(void (^)(BOOL on, NSString *_Nullable why))then;

/// Asks the server now, and posts a notification if more requests are waiting than last time.
/// Used by the background task and on every launch.
+ (void)checkAndNotify:(void (^_Nullable)(BOOL foundSomething))then;

/// Asks iOS to run the task again. Called when the app goes to the background.
+ (void)schedule;

@end

NS_ASSUME_NONNULL_END
