// A shim: the carried-over files import this path by name. See Localization.h.
#import <Foundation/Foundation.h>

@interface YTIFormattedString : NSObject
+ (instancetype)formattedStringWithString:(NSString *)string;
@property (nonatomic, copy) NSString *string;
@end
