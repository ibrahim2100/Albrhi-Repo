#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"
#import "../../Downloader/SCIMediaDownloader.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

#import <substrate.h>
#import <objc/runtime.h>

///
/// Saves a voice message — beta.
///
/// A voice note is the one thing in a chat with no way out of it. The URL is
/// there: a message holds an IGDirectAudio, which holds the IGAudio the app
/// actually plays, which knows its playback URL.
///
/// Long-pressing a voice message asks whether to save it. The download does not
/// belong to a menu item: those are built by IGDSPrismMenuView from an element
/// type this project has not seen, and a long-press that saved without asking
/// would be the wrong behaviour. A prompt gets consent without needing that type,
/// and the whole thing stays off until switched on.
///
/// Beta because that menu is a Swift class whose name carries its module
/// mangling, and mangled names change more readily than ordinary ones. When it
/// does change the entry simply stops appearing — the download path itself, and
/// everything else, is untouched. Diagnostics reports whether the hook attached,
/// so that is answerable without guesswork.
///
/// Hook points identified from RyukGram (github.com/faroukbmiled/RyukGram,
/// GPLv3), a fellow SCInsta fork.
///

@interface SCIAudioMessagePrompt : NSObject
+ (void)askFor:(NSURL *)audio;
@end

@implementation SCIAudioMessagePrompt

/// The last URL asked about, and when. Instagram rebuilds the menu configuration
/// several times for one long-press, which would otherwise stack identical
/// alerts — but the guard expires, so declining once does not make the message
/// unsaveable for the rest of the session.
static NSString *sciLastAsked = nil;
static NSTimeInterval sciLastAskedAt = 0;

+ (void)askFor:(NSURL *)audio {
    if (!audio) return;

    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    BOOL sameMessage = sciLastAsked && [sciLastAsked isEqualToString:audio.absoluteString];
    if (sameMessage && now - sciLastAskedAt < 3.0) return;

    sciLastAsked = audio.absoluteString;
    sciLastAskedAt = now;

    UIViewController *host = topMostController();
    if (!host || host.presentedViewController) return;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:SCILocalized(@"dlaudio_title")
                                            message:SCILocalized(@"dlaudio_body")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"dlaudio_save")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        // Through the one download path, so the album, the queue and the
        // confirmations all behave here as they do everywhere else.
        [SCIMediaDownloader downloadURL:audio
                            sourceLabel:SCILocalized(@"dlaudio_source")
                                isVideo:NO];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:SCILocalized(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [host presentViewController:alert animated:YES completion:nil];
}

@end

static NSString *const kMenuClass =
    @"_TtC32IGDirectMessageMenuConfiguration32IGDirectMessageMenuConfiguration";

/// Reads a property by name only when the object actually answers to it.
static id SCIValue(id object, NSString *name) {
    if (!object || !name.length) return nil;

    SEL selector = NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return nil;

    @try { return [object valueForKey:name]; } @catch (__unused id e) { return nil; }
}

/// The playable URL of a voice message, or nil when this is not one.
static NSURL *SCIAudioURLForMessage(id message) {
    id directAudio = SCIValue(message, @"audio");
    if (!directAudio) return nil;

    // The wrapper holds the server's copy in an ivar rather than a property, so
    // it is read directly — object_getInstanceVariable rather than a guess at an
    // accessor that does not exist.
    id serverAudio = nil;
    Ivar ivar = class_getInstanceVariable([directAudio class], "_server_audio");
    if (ivar) serverAudio = object_getIvar(directAudio, ivar);

    if (!serverAudio) serverAudio = SCIValue(directAudio, @"serverAudio");
    if (!serverAudio) return nil;

    id url = SCIValue(serverAudio, @"playbackURL") ?: SCIValue(serverAudio, @"fallbackURL");

    if ([url isKindOfClass:[NSURL class]]) return url;
    if ([url isKindOfClass:[NSString class]]) return [NSURL URLWithString:url];
    return nil;
}

%hook IGDirectMessageMenuConfiguration

+ (id)menuConfigurationWithEligibleOptions:(id)options
                          messageViewModel:(id)viewModel
                               contentType:(NSInteger)contentType
                                 isSticker:(BOOL)isSticker
                            isMusicSticker:(BOOL)isMusicSticker
                          directNuxManager:(id)nuxManager
                       sessionUserDefaults:(id)defaults
                               launcherSet:(id)launcherSet
                               userSession:(id)session
                                tapHandler:(id)tapHandler {

    [SCIDiagnostics recordActionRowClass:@"IGDirectMessageMenuConfiguration (audio menu)"
                            controlCount:0];

    // The message hangs off the view model under one of a few names depending on
    // the build; whichever answers first is the one this build uses.
    id message = SCIValue(viewModel, @"message")
              ?: SCIValue(viewModel, @"publishedMessage")
              ?: SCIValue(viewModel, @"directMessage");

    NSURL *audio = SCIAudioURLForMessage(message);

    [SCIDiagnostics recordAudioMessageProbe:(message != nil)
                                  audioURL:audio.absoluteString
                              messageClass:message ? NSStringFromClass([message class]) : nil];

    if (!audio) return %orig;                                    // not a voice message
    if (![SCIUtils getBoolPref:@"download_audio_message"]) return %orig;

    id original = %orig;

    // Asking rather than acting. This runs when the menu opens, not when an item
    // is chosen — building an item would mean constructing a menu element type
    // this project has not seen — so consent comes from the prompt instead. A
    // long-press that silently downloaded would be the wrong behaviour, and the
    // setting is off until asked for precisely because this is a prompt, not a
    // button.
    dispatch_async(dispatch_get_main_queue(), ^{
        [SCIAudioMessagePrompt askFor:audio];
    });

    return original;
}

%end

%ctor {
    @autoreleasepool {
        // The class name is Swift-mangled, so it cannot be written as a plain
        // %hook target. Registering it by name also means a build that renames it
        // costs this one feature and nothing else.
        Class menu = objc_getClass([kMenuClass UTF8String]);
        if (menu) %init(_ungrouped, IGDirectMessageMenuConfiguration = menu);
    }
}
