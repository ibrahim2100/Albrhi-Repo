//
//  SCIYTSettingRow.h
//  Albrhi for YouTube
//
//  The two shapes a settings row can take, and the section that holds them.
//
//  These lived inside the settings controller's own .m until the screen grew past two
//  hundred lines of section building. They are here now because every feature writes its
//  own page, and a page cannot describe a row it has no name for.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// One row. A plain object rather than a subclass per kind, because the difference between
/// a switch row and a disclosure row is one field, not one class.
typedef NS_ENUM(NSInteger, SCIRowKind) {
    SCIRowKindSwitch,
    SCIRowKindDisclosure,
};

@interface SCIRow : NSObject
@property (nonatomic, assign) SCIRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, copy, nullable) NSString *symbol;
@property (nonatomic, copy, nullable) NSString *prefKey;      ///< switch rows only
@property (nonatomic, copy, nullable) void (^action)(void);   ///< disclosure rows only

+ (instancetype)switchRow:(NSString *)title
                   detail:(nullable NSString *)detail
                   symbol:(nullable NSString *)symbol
                  prefKey:(NSString *)prefKey;

+ (instancetype)disclosureRow:(NSString *)title
                       detail:(nullable NSString *)detail
                       symbol:(nullable NSString *)symbol
                       action:(void (^)(void))action;
@end


@interface SCISection : NSObject
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *footer;
@property (nonatomic, strong) NSArray<SCIRow *> *rows;
@end

NS_ASSUME_NONNULL_END
