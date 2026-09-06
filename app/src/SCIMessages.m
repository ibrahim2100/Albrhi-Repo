#import "SCIMessages.h"
#import "SCIPages.h"
#import "SCIPage.h"

static NSString *SCIKey(SCIMessageKind kind) {
    return [NSString stringWithFormat:@"message-%ld", (long)kind];
}

@implementation SCIMessages

+ (NSString *)nameOf:(SCIMessageKind)kind {
    switch (kind) {
        case SCIMessageWelcome: return @"ترخيص جديد";
        case SCIMessageRenewal: return @"تذكير بالتجديد";
        case SCIMessageExpired: return @"انتهى الترخيص";
        default:                return @"ردّ على طلب";
    }
}

+ (NSString *)defaultFor:(SCIMessageKind)kind {
    switch (kind) {
        case SCIMessageWelcome:
            return @"أهلاً {name} 👋\nتم تفعيل ترخيص البرهي على جهازك.\nالجهاز: {device}\n"
                    "يغطّي: {scope}\nالمدّة: {until}";
        case SCIMessageRenewal:
            return @"أهلاً {name}\nترخيصك ينتهي {until}. تحبّ أجدّده لك؟";
        case SCIMessageExpired:
            return @"أهلاً {name}\nانتهى ترخيصك ({until}). التجديد يستأنف كل شيء كما كان.";
        default:
            return @"أهلاً {name} — بخصوص طلب ترخيص البرهي";
    }
}

+ (NSString *)textFor:(SCIMessageKind)kind {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:SCIKey(kind)];
    return saved.length ? saved : [self defaultFor:kind];
}

+ (void)setText:(NSString *)text for:(SCIMessageKind)kind {
    // Empty restores the built-in one rather than storing nothing, so there is a way back from an
    // edit — the same absent-keeps/empty-clears shape the server uses for a name.
    if (!text.length) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SCIKey(kind)];
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:text forKey:SCIKey(kind)];
}

+ (BOOL)isEdited:(SCIMessageKind)kind {
    return [[NSUserDefaults standardUserDefaults] stringForKey:SCIKey(kind)].length > 0;
}

+ (NSString *)fill:(SCIMessageKind)kind with:(NSDictionary *)licence {
    double until = [licence[@"until"] doubleValue];

    NSDictionary *values = @{
        @"{name}":   licence[@"name"] ?: @"",
        @"{device}": licence[@"key"] ?: licence[@"dev"] ?: @"",
        @"{scope}":  SCIScopeName(licence[@"tier"]),
        @"{until}":  until == 0 ? @"مدى الحياة" : [SCIPage dateFrom:licence[@"until"]],
    };

    NSMutableString *text = [[self textFor:kind] mutableCopy];
    for (NSString *placeholder in values) {
        [text replaceOccurrencesOfString:placeholder withString:values[placeholder]
                                 options:0 range:NSMakeRange(0, text.length)];
    }
    return text;
}

@end
