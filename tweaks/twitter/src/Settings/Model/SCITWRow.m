#import "SCITWRow.h"

@implementation SCITWRow

+ (instancetype)switchRow:(NSString *)title
                     note:(NSString *)note
                   symbol:(NSString *)symbol
                     tint:(UIColor *)tint
                  prefKey:(NSString *)prefKey {
    SCITWRow *row = [[SCITWRow alloc] init];
    row.kind = SCITWRowKindSwitch;
    row.title = title;
    row.note = note;
    row.symbol = symbol;
    row.tint = tint;
    row.prefKey = prefKey;
    return row;
}

+ (instancetype)actionRow:(NSString *)title
                     note:(NSString *)note
                   symbol:(NSString *)symbol
                     tint:(UIColor *)tint
                   action:(void (^)(void))action {
    SCITWRow *row = [[SCITWRow alloc] init];
    row.kind = SCITWRowKindAction;
    row.title = title;
    row.note = note;
    row.symbol = symbol;
    row.tint = tint;
    row.action = action;
    return row;
}

+ (instancetype)infoRow:(NSString *)title value:(NSString * (^)(void))value {
    SCITWRow *row = [[SCITWRow alloc] init];
    row.kind = SCITWRowKindInfo;
    row.title = title;
    row.value = value;
    return row;
}

@end


@implementation SCITWSection

+ (instancetype)titled:(NSString *)title
                footer:(NSString *)footer
                  rows:(NSArray<SCITWRow *> *)rows {
    SCITWSection *section = [[SCITWSection alloc] init];
    section.title = title;
    section.footer = footer;
    section.rows = rows ?: @[];
    return section;
}

@end
