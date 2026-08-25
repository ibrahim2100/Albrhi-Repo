#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "SCITTComments.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import "../Download/SCITTDownload.h"
#import "../../Diagnostics/SCITTDiagnostics.h"
#import "../../SCILog.h"

@interface AWEUserSheetAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) void (^handler)(void);
@end

@interface AWEUserActionSheetView : UIView
- (void)addAction:(id)action;
@end

@interface TTKCommentAppReviewsLongPressHelper : NSObject
@end

/// Whether a class really declares a selector with the encoding this file expects.
///
/// The same gate the extras use, for the same reason: `class_getInstanceMethod` returning non-NULL
/// proves the selector exists and says nothing about its types, and a `%hook` on a method a class
/// does not declare *adds* one -- inventing an API nobody calls.
static BOOL SCITTCommentsEncodingMatches(Class cls, NSString *selector, const char *expected) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selector));
    if (!method) return NO;

    const char *encoding = method_getTypeEncoding(method);
    return encoding && strcmp(encoding, expected) == 0;
}

// MARK: - What a comment carries

///
/// Every picture or sticker on a comment, as URLs.
///
/// The names are read from this build's own `AWECommentModel`: `hasImage` and `hasSticker` (`B`),
/// `imageList` (`NSArray`), and `liveMotionRemoteURLList` for the animated ones. Each hop is asked
/// with `-respondsToSelector:` rather than assumed -- the rule that cost this project three
/// releases when a real selector name turned out to belong to a different class.
///
static NSArray<NSURL *> *SCITTCommentMedia(id model) {
    if (!model) return nil;

    NSMutableArray<NSURL *> *found = [NSMutableArray array];

    for (NSString *name in @[@"imageList", @"liveMotionRemoteURLList"]) {
        SEL selector = NSSelectorFromString(name);
        if (![model respondsToSelector:selector]) continue;

        id list = ((id (*)(id, SEL))objc_msgSend)(model, selector);
        if (![list isKindOfClass:[NSArray class]]) continue;

        for (id entry in (NSArray *)list) {
            // An entry is either a URL model with its own list, or a string already.
            if ([entry isKindOfClass:[NSString class]]) {
                NSURL *url = [NSURL URLWithString:entry];
                if (url) [found addObject:url];
                continue;
            }

            for (NSString *listName in @[@"originURLList", @"URLList", @"urlList"]) {
                SEL listSelector = NSSelectorFromString(listName);
                if (![entry respondsToSelector:listSelector]) continue;

                id urls = ((id (*)(id, SEL))objc_msgSend)(entry, listSelector);
                if (![urls isKindOfClass:[NSArray class]]) continue;

                for (id address in (NSArray *)urls) {
                    if (![address isKindOfClass:[NSString class]]) continue;
                    NSURL *url = [NSURL URLWithString:address];
                    if (url) { [found addObject:url]; break; }
                }
                if (found.count) break;
            }
        }
    }

    return found.count ? found : nil;
}

// MARK: - The pasteboard, without a name in front of the words

///
/// **What Copy leaves behind, cleaned rather than rebuilt.**
///
/// `-copyCommentContent:` is called with the content and writes it; what lands on the pasteboard
/// carries the commenter's name in front of their words. Rather than guess at what the argument is
/// and write our own string -- which would be a guess about a private method's parameter -- the
/// original runs and its result is trimmed afterward. **A post-condition is true whatever the
/// implementation does**, which is the safer half of the same idea as hooking a setter instead of
/// a getter.
///
/// Conservative on purpose: a leading `@handle` or `Name:` is removed only when something is left
/// after it. A comment that *is* a mention keeps its text rather than becoming empty.
///
static NSString *SCITTWithoutLeadingName(NSString *text) {
    if (!text.length) return text;

    static NSRegularExpression *pattern = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pattern = [NSRegularExpression regularExpressionWithPattern:
                   @"\\A\\s*@?[\\w._\\-\\p{Arabic}]{1,32}\\s*[:：]\\s*"
                                                            options:0
                                                              error:nil];
    });

    NSTextCheckingResult *match =
        [pattern firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!match) return text;

    NSString *rest = [[text substringFromIndex:NSMaxRange(match.range)]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return rest.length ? rest : text;
}

%group SCITTCommentCopy

%hook TTKCommentAppReviewsLongPressHelper

- (void)copyCommentContent:(id)content {
    %orig;

    if (!SCIPrefEnabled(SCIPrefCleanCopy)) return;

    UIPasteboard *board = [UIPasteboard generalPasteboard];
    NSString *copied = board.string;
    NSString *cleaned = SCITTWithoutLeadingName(copied);

    if (cleaned.length && ![cleaned isEqualToString:copied]) {
        board.string = cleaned;
        [SCITTDiagnostics recordPrivacyAnswer:@"comment copied without its author's name"];
    }
}

%end

%end

%group SCITTCommentSave

%hook TTKCommentAppReviewsLongPressHelper

- (id)buildActionSheetForModel:(id)model index:(id)index {
    id sheet = %orig;

    if (!SCIPrefEnabled(SCIPrefSaveCommentMedia) || !sheet) return sheet;

    NSArray<NSURL *> *media = SCITTCommentMedia(model);
    if (!media.count) return sheet;

    //
    // **TikTok's own sheet, with one more row in it.**
    //
    // Presenting a second sheet of our own would either cover theirs or replace it, and replacing
    // it would take away Copy, Delete and Translate -- a correct feature applied one step further
    // than it was asked for, which this project has done once and does not intend to again.
    //
    Class actionClass = NSClassFromString(@"AWEUserSheetAction");
    if (!actionClass || ![sheet respondsToSelector:@selector(addAction:)]) return sheet;

    AWEUserSheetAction *save = [[actionClass alloc] init];
    if (![save respondsToSelector:@selector(setTitle:)] ||
        ![save respondsToSelector:@selector(setHandler:)]) return sheet;

    save.title = media.count > 1
        ? [NSString stringWithFormat:SCILocalized(@"comment_save_many"), (unsigned long)media.count]
        : SCILocalized(@"comment_save_one");

    // Each picture is its own group: `+savePhotos:` treats a group as alternatives for one image
    // and takes the first that works, which is not what a list of separate pictures means.
    NSMutableArray<NSArray<NSURL *> *> *groups = [NSMutableArray array];
    for (NSURL *url in media) [groups addObject:@[url]];

    save.handler = ^{
        [SCITTDownload savePhotos:groups];
    };

    [(AWEUserActionSheetView *)sheet addAction:save];
    return sheet;
}

%end

%end

void SCITTInstallComments(void) {
    Class helper = NSClassFromString(@"TTKCommentAppReviewsLongPressHelper");
    if (!helper) {
        SCILogV(@"[AlbrhiTT] comments: TTKCommentAppReviewsLongPressHelper is not in this build");
        return;
    }

    if (SCITTCommentsEncodingMatches(helper, @"copyCommentContent:", "v24@0:8@16")) {
        %init(SCITTCommentCopy);
        SCILogV(@"[AlbrhiTT] comments: %@", @"-copyCommentContent: (clean copy)");
    } else {
        SCILogV(@"[AlbrhiTT] comments: %@", @"TTKCommentAppReviewsLongPressHelper -copyCommentContent:");
    }

    if (SCITTCommentsEncodingMatches(helper, @"buildActionSheetForModel:index:", "@32@0:8@16@24")) {
        %init(SCITTCommentSave);
        SCILogV(@"[AlbrhiTT] comments: %@", @"-buildActionSheetForModel: (save comment media)");
    } else {
        SCILogV(@"[AlbrhiTT] comments: %@", @"TTKCommentAppReviewsLongPressHelper -buildActionSheetForModel:");
    }
}
