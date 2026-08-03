#import "SCIYTSettingRow.h"

@implementation SCIRow

+ (instancetype)switchRow:(NSString *)title
                   detail:(NSString *)detail
                   symbol:(NSString *)symbol
                  prefKey:(NSString *)prefKey {
    SCIRow *row = [[SCIRow alloc] init];
    row.kind = SCIRowKindSwitch;
    row.title = title;
    row.detail = detail;
    row.symbol = symbol;
    row.prefKey = prefKey;
    return row;
}

+ (instancetype)disclosureRow:(NSString *)title
                       detail:(NSString *)detail
                       symbol:(NSString *)symbol
                       action:(void (^)(void))action {
    SCIRow *row = [[SCIRow alloc] init];
    row.kind = SCIRowKindDisclosure;
    row.title = title;
    row.detail = detail;
    row.symbol = symbol;
    row.action = action;
    return row;
}

@end


@implementation SCISection
@end
