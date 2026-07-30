#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../General/SCIDateFormat.h"

///
/// Shows when someone was last active as a real date instead of "Active 2h ago".
///
/// The subtitle is rendered through IGDirectLeftAlignedTitleView, and the date it
/// came from is asked of the view model first. Instagram has used more than one
/// name for it, so each is tried; failing that the wording is read back, which is
/// less precise but still better than nothing.
///
/// The string itself comes from SCIDateFormat rather than a fixed pattern, so this
/// obeys whatever the user chose under Appearance — the same format their feed
/// timestamps use, rather than a second, inconsistent one.
///
/// Hook points identified from RyukGram (github.com/faroukbmiled/RyukGram, GPLv3),
/// a fellow SCInsta fork.
///

/// Calls a zero-argument getter and returns its value as a date.
///
/// The return type is read from the method signature first. -performSelector:
/// assumes an object comes back, so calling it on a method returning a double —
/// which is exactly how a Unix timestamp is often exposed — would hand a
/// non-pointer to isKindOfClass: and crash.
static NSDate *SCIDateByInvoking(id target, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (![target respondsToSelector:selector]) return nil;

    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2) return nil;   // self, _cmd only

    const char *type = signature.methodReturnType;
    if (!type) return nil;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = target;

    @try { [invocation invoke]; } @catch (__unused id e) { return nil; }

    double seconds = 0;

    switch (type[0]) {
        case '@': {
            __unsafe_unretained id object = nil;
            [invocation getReturnValue:&object];

            if ([object isKindOfClass:[NSDate class]]) return object;
            if ([object isKindOfClass:[NSNumber class]]) { seconds = [object doubleValue]; break; }
            return nil;
        }
        case 'd': { [invocation getReturnValue:&seconds]; break; }
        case 'f': { float value = 0; [invocation getReturnValue:&value]; seconds = value; break; }
        case 'q': { long long value = 0; [invocation getReturnValue:&value]; seconds = (double)value; break; }
        case 'l': case 'i': { int value = 0; [invocation getReturnValue:&value]; seconds = (double)value; break; }
        default: return nil;
    }

    // A plausible Unix time, not a count or an identifier that happens to be big.
    if (seconds > 1000000000.0 && seconds < 4000000000.0) {
        return [NSDate dateWithTimeIntervalSince1970:seconds];
    }
    return nil;
}

/// Turns whatever a getter returned into a date, if it can be one.
static NSDate *SCIDateFromValue(id value) {
    if ([value isKindOfClass:[NSDate class]]) return value;

    // Stored as Unix seconds in some builds. The range check keeps a count or an
    // identifier from being mistaken for a timestamp.
    if ([value isKindOfClass:[NSNumber class]]) {
        double seconds = [value doubleValue];
        if (seconds > 1000000000.0 && seconds < 4000000000.0) {
            return [NSDate dateWithTimeIntervalSince1970:seconds];
        }
    }
    return nil;
}

static NSDate *SCILastActiveDate(id viewModel, NSString *currentText) {
    if (viewModel) {
        // Named guesses first — cheap, and right when they are right.
        for (NSString *key in @[@"lastActiveDate", @"lastActive", @"activeDate"]) {
            @try {
                NSDate *date = SCIDateFromValue([viewModel valueForKey:key]);
                if (date) return date;
            } @catch (__unused id e) {}
        }

        // Then ask the runtime what this object actually offers, rather than
        // adding more guesses. A build that renames the property still works.
        for (NSString *needle in @[@"active", @"seen", @"timestamp"]) {
            for (NSString *name in [SCIUtils selectorsMatching:needle onObject:viewModel]) {
                NSDate *date = SCIDateByInvoking(viewModel, name);
                if (date) return date;
            }
        }
    }

    // Nothing on the model: recover what the wording implies. "Active yesterday"
    // fixes the day but not the hour, which is why the model is asked first.
    return [SCIDateFormat dateFromRelativeText:currentText];
}

/// Rewrites whichever subtitle label this build is using.
static void SCIUpdateLastActive(UIView *titleView, id viewModel) {
    if (![SCIUtils getBoolPref:@"dm_full_last_active"]) return;

    for (NSString *key in @[@"subtitleLabel", @"_subtitleView", @"_transitionalSubtitleLabel"]) {
        UILabel *label = nil;
        @try { label = [titleView valueForKey:key]; } @catch (__unused id e) { continue; }

        if (![label isKindOfClass:[UILabel class]] || !label.text.length) continue;

        // Only a presence line is ours to rewrite; a username or typing indicator
        // is left exactly as Instagram wrote it. "Active" covers the worded forms
        // such as "Active yesterday", which carry no number for the pattern below
        // to match — the case this originally missed.
        BOOL presence = [label.text rangeOfString:@"ctive" options:NSCaseInsensitiveSearch].location != NSNotFound
                     || [label.text rangeOfString:@"نشط"].location != NSNotFound;

        if (!presence && ![SCIDateFormat isRelativeTimestamp:label.text]) continue;

        // "Active now" is a state, not a time; turning it into a date would read
        // as though the person left.
        if ([label.text rangeOfString:@"now" options:NSCaseInsensitiveSearch].location != NSNotFound
            || [label.text rangeOfString:@"الآن"].location != NSNotFound) {
            continue;
        }

        NSDate *date = SCILastActiveDate(viewModel, label.text);
        if (!date) continue;

        NSString *formatted = [SCIDateFormat stringForDate:date original:label.text];
        if (formatted.length) label.text = formatted;
    }
}

%hook IGDirectLeftAlignedTitleView

- (void)setTitleViewModel:(id)viewModel {
    %orig;
    SCIUpdateLastActive(self, viewModel);
}

// The subtitle is re-applied as the header animates in, which would otherwise
// put Instagram's own wording straight back.
- (void)animationCoordinatorDidUpdate:(id)coordinator {
    %orig;

    id viewModel = nil;
    @try { viewModel = [self valueForKey:@"titleViewModel"]; } @catch (__unused id e) {}

    SCIUpdateLastActive(self, viewModel);
}

%end
