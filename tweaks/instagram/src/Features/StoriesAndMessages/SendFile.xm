#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"

#import <substrate.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

///
/// Sends an arbitrary file in a DM — beta.
///
/// Instagram's composer offers photos, video and audio but no general file, while
/// the sender underneath is perfectly capable of one. An entry is added to the
/// plus-button sheet, the file is chosen with the system picker, and it goes
/// through Instagram's own send path.
///
/// Beta, and labelled so in the settings: the send selector carries nine
/// arguments whose meanings are not documented anywhere, and only three are known
/// with confidence. If a future build renames it, the entry stops appearing —
/// nothing else breaks.
///
/// Hook points identified from RyukGram (github.com/faroukbmiled/RyukGram,
/// GPLv3), a fellow SCInsta fork.
///

static NSString *const kSendFileSelector =
    @"sendFileWithURL:threadKey:attribution:replyMessagePk:quotedPublishedMessage:"
    @"messageSentSpeedLogger:messageSentSpeedMarker:localSendSpeedLogger:localSendSpeedMarker:";

// Set while the composer's overflow menu is being built, so the hook on IGDSMenu
// only touches that one sheet and not every menu in the app.
static __weak IGDirectThreadViewController *sciComposerThread = nil;

@interface SCISendFile : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, weak) IGDirectThreadViewController *thread;
@end

@implementation SCISendFile

// Retained for as long as the picker is up; the picker only holds its delegate
// weakly, so a local would be gone before the user chose anything.
static SCISendFile *sciPickerDelegate = nil;

+ (void)presentFromThread:(IGDirectThreadViewController *)thread {
    if (!thread) return;

    sciPickerDelegate = [[SCISendFile alloc] init];
    sciPickerDelegate.thread = thread;

    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeItem]];
    picker.delegate = sciPickerDelegate;
    picker.allowsMultipleSelection = NO;

    [thread presentViewController:picker animated:YES completion:nil];
}

/// Finds the object that actually sends, and asks it to send the file.
///
/// The sender is reached by name because it is not exposed on the controller's
/// interface. Each candidate is checked rather than assumed, so a renamed
/// property degrades to a message the user can act on.
- (void)send:(NSURL *)url {
    IGDirectThreadViewController *thread = self.thread;
    if (!thread) return;

    id sender = nil;
    for (NSString *key in @[@"messageSender", @"_messageSender", @"sender", @"directMessageSender"]) {
        @try { sender = [thread valueForKey:key]; } @catch (__unused id e) {}
        if (sender) break;
    }

    id threadKey = nil;
    for (NSString *key in @[@"threadKey", @"_threadKey"]) {
        @try { threadKey = [thread valueForKey:key]; } @catch (__unused id e) {}
        if (threadKey) break;
    }

    SEL selector = NSSelectorFromString(kSendFileSelector);

    if (!sender || !threadKey || ![sender respondsToSelector:selector]) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"sendfile_unavailable")];
        return;
    }

    NSMethodSignature *signature = [sender methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 11) {   // self, _cmd, then nine
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"sendfile_unavailable")];
        return;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = sender;

    [invocation setArgument:&url atIndex:2];
    [invocation setArgument:&threadKey atIndex:3];

    // The remaining seven are attribution and telemetry; Instagram tolerates nil
    // for all of them, and we have nothing meaningful to put there.
    id nothing = nil;
    for (NSInteger i = 4; i <= 10; i++) [invocation setArgument:&nothing atIndex:i];

    @try {
        [invocation invoke];
        [SCIUtils showSuccessHUDWithDescription:SCILocalized(@"sendfile_sent")];
    } @catch (__unused id e) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"sendfile_unavailable")];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    // A picked file lives outside the sandbox until copied, and the send is
    // asynchronous — so it is brought inside first rather than handing over a URL
    // that stops being readable the moment this method returns.
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (scoped) [url stopAccessingSecurityScopedResource];

    if (!data) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"sendfile_unreadable")];
        return;
    }

    NSString *local = [NSTemporaryDirectory() stringByAppendingPathComponent:url.lastPathComponent];
    [data writeToFile:local atomically:YES];

    [self send:[NSURL fileURLWithPath:local]];
    sciPickerDelegate = nil;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    sciPickerDelegate = nil;
}

@end

// MARK: - Hooks

%hook IGDirectThreadViewController

- (void)composerOverflowButtonMenuWillPrepareExpandWithPlusButton:(id)button {
    // Marks the sheet about to be built as the composer's, so the IGDSMenu hook
    // below can tell it from every other menu in the app.
    sciComposerThread = self;
    %orig;
}

%end

%hook IGDSMenu

- (instancetype)initWithMenuItems:(NSArray *)items edr:(id)edr headerLabelText:(NSString *)header {
    if (![SCIUtils getBoolPref:@"send_file"] || !sciComposerThread) {
        return %orig;
    }

    IGDirectThreadViewController *thread = sciComposerThread;
    sciComposerThread = nil;   // one sheet only

    Class itemClass = objc_getClass("IGDSMenuItem");
    if (!itemClass) return %orig;

    IGDSMenuItem *entry = [[itemClass alloc]
        initWithTitle:SCILocalized(@"sendfile_menu")
                image:[UIImage systemImageNamed:@"doc.badge.plus"]
              handler:^{ [SCISendFile presentFromThread:thread]; }];

    if (!entry) return %orig;

    NSMutableArray *combined = [NSMutableArray arrayWithObject:entry];
    [combined addObjectsFromArray:items ?: @[]];

    return %orig(combined, edr, header);
}

%end
