//
//  SCIMessages.h
//  Albrhi Licences — what gets written into WhatsApp, and by whom.
//
//  **A sentence compiled into the app is a sentence nobody can fix at the moment it is wrong.**
//  The first version wrote one message in the code; every licence sold goes out through one of
//  these, and the wording of a renewal reminder is exactly the kind of thing that gets changed
//  after the third person misreads it.
//
//  The placeholders are filled from the licence itself. An unknown one is left as it is rather
//  than blanked: a message reading «{naem}» is obviously a typo in the template, while an empty
//  gap is a message that looks finished and says nothing.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCIMessageKind) {
    SCIMessageWelcome = 0,   ///< a licence has just been issued
    SCIMessageRenewal,       ///< it ends soon
    SCIMessageExpired,       ///< it has ended
    SCIMessageRequest,       ///< answering somebody who asked for one
    SCIMessageCount
};

@interface SCIMessages : NSObject

+ (NSString *)nameOf:(SCIMessageKind)kind;      ///< what the row is called
+ (NSString *)textFor:(SCIMessageKind)kind;     ///< the template, edited or built in
+ (void)setText:(nullable NSString *)text for:(SCIMessageKind)kind;   ///< nil restores the default
+ (BOOL)isEdited:(SCIMessageKind)kind;

/// The template with `{name}`, `{device}`, `{scope}` and `{until}` filled in.
+ (NSString *)fill:(SCIMessageKind)kind with:(NSDictionary *)licence;

@end

NS_ASSUME_NONNULL_END
