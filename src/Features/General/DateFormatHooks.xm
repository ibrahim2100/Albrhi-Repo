#import <substrate.h>
#import <objc/runtime.h>
#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "SCIDateFormat.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

///
/// Applies the custom date format everywhere Instagram writes a time.
///
/// Instagram adds its own category methods to NSDate — -formattedDateRelativeToNow
/// and friends — and every surface asks a date to describe itself through them.
/// Hooking those reaches feed, stories and messages at once, and the result is
/// exact: the receiver *is* the date, so nothing has to be inferred from wording
/// the way parsing "3 hours ago" would.
///
/// Earlier attempts hooked the view (IGCoreTextView) and never fired, because the
/// text there reads "3 hours ago ⋅ See translation" — a timestamp glued to other
/// content. At this level that problem does not arise.
///
/// The selector names were identified from RyukGram
/// (github.com/faroukbmiled/RyukGram, GPLv3), another SCInsta fork. What was taken
/// is the knowledge of where to attach; the formatting is Albrhi's own.
///

// MARK: - Original implementations

// Every hooked selector keeps its own original. Sharing one pointer across
// several would mean the last install overwrote the rest, and each call would
// then run the wrong original — silently returning another method's answer.
#define SCI_MAX_DATE_HOOKS 16

static struct { SEL selector; IMP original; } sHooked[SCI_MAX_DATE_HOOKS];
static size_t sHookedCount = 0;

/// Filled once during %ctor and only read afterwards, so no locking is needed on
/// a path that runs for every timestamp drawn.
static IMP SCIOriginalFor(SEL selector) {
    for (size_t i = 0; i < sHookedCount; i++) {
        if (sHooked[i].selector == selector) return sHooked[i].original;
    }
    return NULL;
}

static NSString *SCIFormattedOrNil(NSDate *date) {
    if (![date isKindOfClass:[NSDate class]]) return nil;
    if (![SCIDateFormat enabled]) return nil;
    return [SCIDateFormat stringForDate:date original:nil];
}

// MARK: - Trampolines

// One per arity. The original is only called when there is nothing to replace it
// with, which keeps the common case to a single format.
static NSString *hook_zero(NSDate *self, SEL _cmd) {
    NSString *replacement = SCIFormattedOrNil(self);
    if (replacement) {
        [SCIDiagnostics recordDateRewrite:NSStringFromSelector(_cmd) exact:YES];
        return replacement;
    }
    IMP original = SCIOriginalFor(_cmd);
    return original ? ((NSString *(*)(NSDate *, SEL))original)(self, _cmd) : nil;
}

static NSString *hook_one(NSDate *self, SEL _cmd, BOOL a1) {
    NSString *replacement = SCIFormattedOrNil(self);
    if (replacement) {
        [SCIDiagnostics recordDateRewrite:NSStringFromSelector(_cmd) exact:YES];
        return replacement;
    }
    IMP original = SCIOriginalFor(_cmd);
    return original ? ((NSString *(*)(NSDate *, SEL, BOOL))original)(self, _cmd, a1) : nil;
}

static NSString *hook_two(NSDate *self, SEL _cmd, BOOL a1, BOOL a2) {
    NSString *replacement = SCIFormattedOrNil(self);
    if (replacement) {
        [SCIDiagnostics recordDateRewrite:NSStringFromSelector(_cmd) exact:YES];
        return replacement;
    }
    IMP original = SCIOriginalFor(_cmd);
    return original ? ((NSString *(*)(NSDate *, SEL, BOOL, BOOL))original)(self, _cmd, a1, a2) : nil;
}

// MARK: - Installation

static void SCIInstall(NSString *name, IMP replacement) {
    if (sHookedCount >= SCI_MAX_DATE_HOOKS) return;

    SEL selector = NSSelectorFromString(name);
    if (!selector) return;

    // Absent in this Instagram build: skipping is correct, and leaves the other
    // selectors working rather than failing the whole feature.
    if (!class_getInstanceMethod([NSDate class], selector)) return;

    IMP original = NULL;
    MSHookMessageEx([NSDate class], selector, replacement, &original);
    if (!original) return;

    sHooked[sHookedCount].selector = selector;
    sHooked[sHookedCount].original = original;
    sHookedCount++;
}

%ctor {
    @autoreleasepool {
        NSArray<NSString *> *zeroArgument = @[
            @"formattedDateInMixedFormat",
            @"formattedDateRelativeToNow",
            @"shortenedFormattedDateRelativeToNow",
            @"partiallyShortenedFormattedDateRelativeToNow",
            @"shortenedFormattedDateRelativeToNowIncludeYears",
        ];
        NSArray<NSString *> *oneArgument = @[
            @"shortenedFormattedDateRelativeToNowHideSeconds:",
            @"formattedDateRelativeToNowHideSeconds:",
            @"formattedDateRelativeToNowIncludingYearsHideSeconds:",
        ];
        NSArray<NSString *> *twoArguments = @[
            @"formattedDateRelativeToNowHideSeconds:shouldFloorDaysWeeks:",
            @"shortenedFormattedDateRelativeToNowHideSeconds:shouldFloorDaysWeeks:",
        ];

        for (NSString *name in zeroArgument) SCIInstall(name, (IMP)hook_zero);
        for (NSString *name in oneArgument)  SCIInstall(name, (IMP)hook_one);
        for (NSString *name in twoArguments) SCIInstall(name, (IMP)hook_two);

        [SCIDiagnostics recordDateHooksInstalled:(NSInteger)sHookedCount];
    }
}
