#import <UIKit/UIKit.h>
#import "SCITWExtras.h"
#import "Prefs.h"
#import "SCILog.h"

@interface T1StandardStatusAttachmentViewAdapter : NSObject
@property (nonatomic, assign, readonly) NSUInteger attachmentType;
@end

static BOOL sciOn(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static BOOL sciUndoPresent = NO, sciBioPresent = NO, sciUploadPresent = NO;
static BOOL sciAttachmentPresent = NO, sciTypeaheadPresent = NO;
static NSUInteger sciUndoForced = 0, sciBioForced = 0, sciUploadForced = 0;
static NSUInteger sciFullFramed = 0, sciQueriesWithheld = 0, sciRTLForced = 0;


%group ExtrasUndo

%hook TFNTwitterToastNudgeExperimentModel

/// The toast that offers to take a post back. X decides whether to show it from an
/// experiment; this answers yes when asked to.
- (BOOL)shouldShowShowUndoTweetSentToast {
    if (!sciOn(SCIPrefUndoPost)) return %orig;
    sciUndoForced++;
    return YES;
}

%end

%end


%group ExtrasBio

%hook TFNTwitterCanonicalUser

- (BOOL)isProfileBioTranslatable {
    if (!sciOn(SCIPrefBioTranslate)) return %orig;
    sciBioForced++;
    return YES;
}

%end

%end


%group ExtrasUpload

%hook TTMUploadConfiguration

/// Not the upload quality itself -- whether X shows the setting that controls it. The class
/// is `TTMUploadConfiguration` here; BHTwitter names `TFNTwitterMediaUploadConfiguration`,
/// which is not in this build, and taking its name on trust is exactly the mistake this
/// project has three entries in CLAUDE.md about.
- (BOOL)photoUploadHighQualityImagesSettingIsVisible {
    if (!sciOn(SCIPrefHighQualityUpload)) return %orig;
    sciUploadForced++;
    return YES;
}

%end

%end


%group ExtrasAttachment

%hook T1StandardStatusAttachmentViewAdapter

/// A single photo drawn whole instead of cropped to a strip.
///
/// Only for attachment type 2, which is what keeps this from touching a video, a card or a
/// multi-photo grid -- three things a display type of 1 would mean something else for.
- (NSUInteger)displayType {
    if (!sciOn(SCIPrefFullFrameImages)) return %orig;
    if (self.attachmentType != 2) return %orig;

    sciFullFramed++;
    return 1;
}

%end

%end


%group ExtrasTypeahead

%hook TTSSearchTypeaheadViewController

/// Withheld at the setter rather than emptied at the view.
///
/// The class is `TTSSearchTypeaheadViewController` in this build --
/// `T1SearchTypeaheadViewController` is gone -- and `-setRecentQueries:` is a better point
/// than the `-viewDidLoad` a reference tweak uses: nothing downstream is ever handed a list
/// to draw and then asked to un-draw it.
- (void)setRecentQueries:(NSArray *)queries {
    if (!sciOn(SCIPrefNoSearchHistory)) {
        %orig;
        return;
    }
    sciQueriesWithheld++;
    %orig(@[]);
}

%end

%end


%group ExtrasRTL

%hook NSParagraphStyle

+ (NSWritingDirection)defaultWritingDirectionForLanguage:(id)language {
    if (!sciOn(SCIPrefDisableRTL)) return %orig;
    sciRTLForced++;
    return NSWritingDirectionLeftToRight;
}

%end

%end


NSString *SCITWExtrasReport(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (!sciUndoPresent) [parts addObject:@"undo: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"undo %lu", (unsigned long)sciUndoForced]];

    if (!sciBioPresent) [parts addObject:@"bio: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"bio %lu", (unsigned long)sciBioForced]];

    if (!sciUploadPresent) [parts addObject:@"upload: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"upload %lu", (unsigned long)sciUploadForced]];

    if (!sciAttachmentPresent) [parts addObject:@"full frame: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"full frame %lu", (unsigned long)sciFullFramed]];

    if (!sciTypeaheadPresent) [parts addObject:@"search history: class absent"];
    else [parts addObject:[NSString stringWithFormat:@"queries withheld %lu",
                           (unsigned long)sciQueriesWithheld]];

    [parts addObject:[NSString stringWithFormat:@"ltr %lu", (unsigned long)sciRTLForced]];

    return [@"extras: " stringByAppendingString:[parts componentsJoinedByString:@" · "]];
}

void SCITWInstallExtras(void) {
    sciUndoPresent = (NSClassFromString(@"TFNTwitterToastNudgeExperimentModel") != nil);
    if (sciUndoPresent) {
        %init(ExtrasUndo);
    }

    sciBioPresent = (NSClassFromString(@"TFNTwitterCanonicalUser") != nil);
    if (sciBioPresent) {
        %init(ExtrasBio);
    }

    sciUploadPresent = (NSClassFromString(@"TTMUploadConfiguration") != nil);
    if (sciUploadPresent) {
        %init(ExtrasUpload);
    }

    sciAttachmentPresent = (NSClassFromString(@"T1StandardStatusAttachmentViewAdapter") != nil);
    if (sciAttachmentPresent) {
        %init(ExtrasAttachment);
    }

    sciTypeaheadPresent = (NSClassFromString(@"TTSSearchTypeaheadViewController") != nil);
    if (sciTypeaheadPresent) {
        %init(ExtrasTypeahead);
    }

    // No presence check: NSParagraphStyle is Foundation's and is always there.
    %init(ExtrasRTL);

    SCILogV(@"extras: undo %d, bio %d, upload %d, attachment %d, typeahead %d",
            sciUndoPresent, sciBioPresent, sciUploadPresent,
            sciAttachmentPresent, sciTypeaheadPresent);
}
