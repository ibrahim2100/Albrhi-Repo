#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Localization/SCILocalize.h"
#import "../../Settings/SCIDiagnosticsViewController.h"

#import <substrate.h>
#import <objc/runtime.h>

///
/// Groundwork for saving a voice message — beta, and not yet wired to a button.
///
/// A voice note is the one thing in a chat with no way out of it. The URL is
/// there: a message holds an IGDirectAudio, which holds the IGAudio the app
/// actually plays, which knows its playback URL.
///
/// What is missing is only where to put the button. It belongs in the message's
/// long-press menu, but that menu's items are built by IGDSPrismMenuView from an
/// element type this project has not seen, and adding a download that fired when
/// the menu merely opened — rather than when the user chose it — would be worse
/// than not having one. So this resolves the URL, reports it, and stops there.
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

static NSURL *sciLastAudioURL = nil;

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

    // Remembered, not acted on. Downloading here would fire the moment the menu
    // opened rather than when the user chose to — the button that should trigger
    // it lives in IGDSPrismMenuView, whose element type is not known yet, so this
    // reports what it can resolve and waits.
    [SCIDiagnostics recordAudioMessageProbe:(message != nil)
                                  audioURL:audio.absoluteString
                              messageClass:message ? NSStringFromClass([message class]) : nil];

    if (audio) sciLastAudioURL = audio;

    return %orig;
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
